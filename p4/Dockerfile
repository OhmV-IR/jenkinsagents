FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required system tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    procps \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Add and verify Perforce GPG key, then configure repository for Ubuntu 24.04 (noble)
RUN wget -qO - https://package.perforce.com/perforce.pubkey | gpg --dearmor | tee /usr/share/keyrings/perforce.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu noble release" | tee /etc/apt/sources.list.d/perforce.list

# Install Perforce Server (p4d / p4-server)
RUN apt-get update && apt-get install -y p4-server && \
    rm -rf /var/lib/apt/lists/*

# Environment variables for default non-interactive server configuration
ENV P4NAME=p4depot \
    P4PORT=1666 \
    P4ROOT=/p4root \
    P4USER=p4admin \
    P4PASS=SuperSecurePassword123! \
    P4UNICODE=0 \
    P4CASESENSITIVE=1

# Expose default Perforce port
EXPOSE 1666

# Entrypoint script to run post-installation configuration if not already configured
RUN echo '#!/bin/bash\n\
if [ ! -d "$P4ROOT/db.config" ]; then\n\
    echo "Configuring Perforce service..."\n\
    mkdir -p "$P4ROOT"\n\
    UNICODE_FLAG=""\n\
    if [ "$P4UNICODE" = "1" ]; then UNICODE_FLAG="-u"; fi\n\
    CASE_FLAG=""\n\
    if [ "$P4CASESENSITIVE" = "0" ]; then CASE_FLAG="-C 1"; fi\n\
    /opt/perforce/sbin/configure-p4d.sh "$P4NAME" -p "$P4PORT" -r "$P4ROOT" -u "$P4USER" -P "$P4PASS" $UNICODE_FLAG $CASE_FLAG --no-start\n\
fi\n\
exec /usr/bin/p4dctl start "$P4NAME" && tail -f "$P4ROOT/log"\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
