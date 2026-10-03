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

# Expose default Perforce port
EXPOSE 1666

ENTRYPOINT ["/bin/bash"]
