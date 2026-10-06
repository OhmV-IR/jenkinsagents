#!/bin/bash
# Entrypoint of the p4-server image.
#
#   p4d-entrypoint.sh              configure the p4d service on first boot, start it under p4dctl,
#                                  and keep the container alive for exactly as long as p4d answers
#   p4d-entrypoint.sh healthcheck  exit 0 if p4d answers on P4PORT (used by HEALTHCHECK)
#
# Settings (environment):
#   P4NAME           p4dctl service name / server id       (default p4depot)
#   P4PORT           port p4d listens on, e.g. 1666 or ssl:1666 (default 1666)
#   P4ROOT           server root (versioned files + db)      (default /p4root)
#   P4USER, P4PASS   super user created on first boot; P4PASS is only required then
#   P4CASESENSITIVE  1 = case-sensitive server, 0 = case-insensitive (default 1). First boot only:
#                    a server's case handling cannot be changed after it is created.
#   P4UNICODE        1 = unicode-mode server (default 0). First boot only.
set -euo pipefail

P4NAME="${P4NAME:-p4depot}"
P4PORT="${P4PORT:-1666}"
P4ROOT="${P4ROOT:-/p4root}"
P4USER="${P4USER:-p4admin}"
P4CASESENSITIVE="${P4CASESENSITIVE:-1}"
P4UNICODE="${P4UNICODE:-0}"

SERVICE_CONF="/etc/perforce/p4dctl.conf.d/${P4NAME}.conf"
# Local address to probe the server on: same protocol and port as P4PORT, on localhost.
PROBE_PORT="localhost:${P4PORT##*:}"
[[ "$P4PORT" == ssl* ]] && PROBE_PORT="ssl:${PROBE_PORT}"

log() { echo "[p4d-entrypoint] $*"; }
die() { echo "[p4d-entrypoint] ERROR: $*" >&2; exit 1; }

# True if p4d answers on P4PORT. This talks to the server itself rather than grepping
# `p4dctl status` (whose "not running" also contains "running").
p4d_answers() {
	if [[ "$PROBE_PORT" == ssl:* ]]; then
		p4 -p "$PROBE_PORT" trust -y >/dev/null 2>&1 || return 1
	fi
	p4 -p "$PROBE_PORT" -u healthcheck info -s >/dev/null 2>&1
}

if [ "${1:-}" = "healthcheck" ]; then
	p4d_answers
	exit $?
fi

configure_script() {
	# configure-p4d.sh since the 2025 "P4" rename of the packages, configure-helix-p4d.sh before.
	local script
	for script in /opt/perforce/sbin/configure-p4d.sh /opt/perforce/sbin/configure-helix-p4d.sh; do
		if [ -x "$script" ]; then echo "$script"; return 0; fi
	done
	die "no p4d configure script found in /opt/perforce/sbin"
}

# Recreates the p4dctl service definition for an existing server root, for when the
# /etc/perforce volume was lost but the data volume survived.
write_service_conf() {
	mkdir -p "$(dirname "$SERVICE_CONF")"
	cat > "$SERVICE_CONF" <<-EOF
	p4d ${P4NAME}
	{
	    Owner    = perforce
	    Execute  = $(command -v p4d)
	    Umask    = 077
	    Enabled  = true
	    Environment
	    {
	        P4ROOT   = ${P4ROOT}
	        P4SSLDIR = ssl
	        P4PORT   = ${P4PORT}
	        P4NAME   = ${P4NAME}
	        PATH     = /bin:/usr/bin:/usr/local/bin:/opt/perforce/bin:/opt/perforce/sbin
	    }
	}
	EOF
}

# The server root must belong to the perforce user that p4dctl runs p4d as. Only the top level is
# fixed here; p4d itself creates everything below it as perforce.
mkdir -p "$P4ROOT"
chown perforce:perforce "$P4ROOT"
chmod 0700 "$P4ROOT"

if [ -e "$P4ROOT/db.counters" ]; then
	# Existing server.
	if [ ! -f "$SERVICE_CONF" ]; then
		log "server root $P4ROOT exists but $SERVICE_CONF is missing; recreating the p4dctl service definition"
		write_service_conf
	fi
else
	# No server yet. Refuse if a service definition already exists: that means the data volume was
	# not mounted (or was wiped), and silently starting an empty depot would hide that.
	if [ -f "$SERVICE_CONF" ]; then
		die "$SERVICE_CONF exists but $P4ROOT holds no server (no db.counters). Is the data volume mounted?" \
			"To deliberately start over with an empty depot, delete $SERVICE_CONF first."
	fi
	[ -n "${P4PASS:-}" ] || die "P4PASS must be set to create the server (super user '$P4USER' password)"
	case "$P4CASESENSITIVE" in
		1) case_insensitive=0 ;;
		0) case_insensitive=1 ;;
		*) die "P4CASESENSITIVE must be 1 (case-sensitive) or 0 (case-insensitive), got '$P4CASESENSITIVE'" ;;
	esac
	# The configure script's --case takes a case-INSENSITIVITY flag (0 = sensitive, 1 = insensitive).
	args=("$P4NAME" -n -p "$P4PORT" -r "$P4ROOT" -u "$P4USER" -P "$P4PASS" --case "$case_insensitive")
	case "$P4UNICODE" in
		1) args+=(--unicode) ;;
		0) ;;
		*) die "P4UNICODE must be 1 or 0, got '$P4UNICODE'" ;;
	esac
	log "creating server '$P4NAME' in $P4ROOT (port $P4PORT, case-sensitive=$P4CASESENSITIVE, unicode=$P4UNICODE, super user $P4USER)"
	# P4SSLDIR is $P4ROOT/ssl and must exist (0700, owned by perforce) for ssl: ports.
	install -d -o perforce -g perforce -m 0700 "$P4ROOT/ssl"
	script="$(configure_script)"
	"$script" "${args[@]}"
fi

# Nothing can be running when the container (re)starts, so any p4dctl/p4d pid file left by an
# unclean stop is stale; with PIDs reused in a fresh PID namespace it could make p4dctl believe
# p4d is already running.
rm -f /var/run/p4d.*.pid /var/run/p4dctl.*

# The configure script may already have started the server.
if ! p4d_answers; then
	log "starting p4d service '$P4NAME'"
	p4dctl start -t p4d "$P4NAME"
fi
for _ in $(seq 1 60); do
	p4d_answers && break
	sleep 1
done
p4d_answers || die "p4d did not start answering on $PROBE_PORT"
log "p4d '$P4NAME' is up on $P4PORT"

# Stop p4d cleanly on `docker stop` (SIGTERM) so the journal and db are left consistent.
stopping=0
shutdown() {
	stopping=1
	log "stopping p4d service '$P4NAME'"
	p4dctl stop -t p4d "$P4NAME" || true
	if [ -n "${tail_pid:-}" ]; then kill "$tail_pid" 2>/dev/null || true; fi
	exit 0
}
trap shutdown TERM INT

# Mirror the server log to the container log (docker logs) when p4d writes one to P4ROOT.
tail -n 0 -F "$P4ROOT/log" 2>/dev/null &
tail_pid=$!

# Stay alive while p4d answers; exit after several consecutive failures so the restart policy
# brings the whole service back.
failures=0
while [ "$stopping" -eq 0 ]; do
	sleep 10 & wait $! || true
	if p4d_answers; then
		failures=0
	else
		failures=$((failures + 1))
		log "p4d did not answer on $PROBE_PORT ($failures/3)"
		if [ "$failures" -ge 3 ]; then
			kill "$tail_pid" 2>/dev/null || true
			die "p4d stopped answering; exiting so the container restart policy can recover it"
		fi
	fi
done
