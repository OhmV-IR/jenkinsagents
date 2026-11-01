#!/bin/bash
# Enrols the WARP client in a Zero Trust organisation with a service token (no browser login) and
# keeps it connected. Needs NET_ADMIN, /dev/net/tun and net.ipv4.conf.all.src_valid_mark=1.
#   WARP_TEAM_NAME      Zero Trust team name (<team>.cloudflareaccess.com)
#   WARP_CLIENT_ID      service token Client ID
#   WARP_CLIENT_SECRET  service token Client Secret
set -euo pipefail

: "${WARP_TEAM_NAME:?set WARP_TEAM_NAME}"
: "${WARP_CLIENT_ID:?set WARP_CLIENT_ID}"
: "${WARP_CLIENT_SECRET:?set WARP_CLIENT_SECRET}"

mkdir -p /var/lib/cloudflare-warp /run/dbus
rm -f /run/dbus/pid
dbus-daemon --system --fork

cat > /var/lib/cloudflare-warp/mdm.xml <<XML
<dict>
  <key>organization</key><string>${WARP_TEAM_NAME}</string>
  <key>auth_client_id</key><string>${WARP_CLIENT_ID}</string>
  <key>auth_client_secret</key><string>${WARP_CLIENT_SECRET}</string>
  <key>service_mode</key><string>warp</string>
  <key>auto_connect</key><integer>1</integer>
  <key>switch_locked</key><true/>
</dict>
XML
chmod 600 /var/lib/cloudflare-warp/mdm.xml

warp-svc --accept-tos &
svc_pid=$!

for _ in $(seq 1 30); do
	warp-cli --accept-tos status >/dev/null 2>&1 && break
	sleep 1
done

warp-cli --accept-tos connect || true

# Let other containers' traffic that is routed through this one (not only the ones sharing the namespace)
# be NATed into the tunnel.
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
iptables -t nat -C POSTROUTING -o CloudflareWARP -j MASQUERADE 2>/dev/null || \
	iptables -t nat -A POSTROUTING -o CloudflareWARP -j MASQUERADE || true

wait "${svc_pid}"
