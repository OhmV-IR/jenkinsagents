# syntax=docker/dockerfile:1
# Cloudflare WARP (Zero Trust) client in full-tunnel mode, used as a network sidecar: agent containers
# join its network namespace (network_mode: "service:warp") so all their traffic, including the private
# CIDR route to the Perforce server, goes through WARP.
#   docker build -t warp-sidecar:latest -f warp/Dockerfile warp
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg iproute2 iptables dbus procps && \
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp.gpg] https://pkg.cloudflareclient.com/ noble main" \
        > /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && apt-get install -y --no-install-recommends cloudflare-warp && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 warp-entrypoint.sh /usr/local/bin/warp-entrypoint.sh

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=3 \
    CMD warp-cli --accept-tos status | grep -q "Connected"

ENTRYPOINT ["/usr/local/bin/warp-entrypoint.sh"]
