# Linux agent (docker-in-docker)

Jenkins agent with an inner dockerd, plus a Cloudflare WARP sidecar (`../warp`) that the agent shares a
network namespace with, so it can reach the Perforce server's private CIDR route.

## Setup

Copy `example.env` to `.env` and fill in `AGENT_NAME`, `AGENT_SECRET` and the `WARP_*` values.

## Run

On a normal Linux host with the Sysbox runtime installed:

```
docker compose up -d
```

### WSL2

Sysbox cannot run on WSL2 (the WSL init already holds a seccomp user-notification listener, so
`sysbox-runc` fails with "error loading seccomp filter ... device or resource busy"). Add the WSL
override, which switches the agent to plain `runc` with `privileged: true`:

```
docker compose -f docker-compose.yml -f docker-compose.wsl.yml up -d
```

Pass the same two `-f` flags to every other compose command (`logs`, `down`, ...), or the override is
dropped. To avoid repeating them, set this in `.env`:

```
COMPOSE_FILE=docker-compose.yml:docker-compose.wsl.yml
```

The `warp` service needs `/dev/net/tun`; if it fails to start under WSL2, check `ls /dev/net/tun`.
