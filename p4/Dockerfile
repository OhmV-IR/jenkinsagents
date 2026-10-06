# syntax=docker/dockerfile:1
# Perforce server (p4d) managed by p4dctl. On first boot the entrypoint creates the server from the
# P4* environment variables; afterwards it just starts it. See p4d-entrypoint.sh for the settings.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Optional exact p4-server package version to pin to (empty = latest). Pinning makes server
# upgrades deliberate: a new major p4d version needs its database upgraded (p4d -xu) on first start.
ARG P4_SERVER_VERSION=""

# Perforce's apt repository (signing key verified by apt) and the p4-server package, which brings
# p4d, the p4 CLI, p4dctl and the configure script, and creates the perforce user. One layer, with
# the apt lists removed in the same step.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg procps && \
    curl -fsSL https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu noble release" \
        > /etc/apt/sources.list.d/perforce.list && \
    apt-get update && \
    apt-get install -y "p4-server${P4_SERVER_VERSION:+=${P4_SERVER_VERSION}}" && \
    command -v p4d && command -v p4 && command -v p4dctl && id perforce && \
    rm -rf /var/lib/apt/lists/*

# Server root, pre-created with the right owner and mode so a fresh named volume mounted here
# inherits them.
RUN install -d -o perforce -g perforce -m 0700 /p4root

ENV P4NAME=p4depot \
    P4PORT=1666 \
    P4ROOT=/p4root \
    P4USER=p4admin

COPY --chmod=0755 p4d-entrypoint.sh /usr/local/bin/p4d-entrypoint.sh

EXPOSE 1666

# Healthy only when p4d actually answers on P4PORT.
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/p4d-entrypoint.sh", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/p4d-entrypoint.sh"]
