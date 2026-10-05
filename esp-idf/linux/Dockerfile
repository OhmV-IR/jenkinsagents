# syntax=docker/dockerfile:1
# ESP-IDF toolchains, installed with Espressif's eim as the jenkins user. This image is the base of
# jenkins-agent-linux, so editing the agent never re-runs the (slow) ESP-IDF install. It is only
# rebuilt on purpose: BUILD_ESP_IDF in the Jenkinsfile, or a change under esp-idf/linux/.
#
# A base image rather than a COPY source: eim installs Python venvs with absolute paths, system
# packages and per-user state, which only stay valid if the agent is built on top of this image.

# uid/gid of the jenkins user; jenkins-agent-linux relies on it (COPY --link --chown).
ARG JENKINS_UID=1001

FROM cruizba/ubuntu-dind:resolute-latest@sha256:04cd04068660769cb917084850f4ef04988c95aa615be83f09fb16a0c2671c08

ENV DEBIAN_FRONTEND=noninteractive

# eim-cli's package dependencies are ESP-IDF's Linux prerequisites (git, cmake, flex, bison, gperf,
# ccache, libffi/libssl, dfu-util, libusb, wget, python3), so apt installs them with it. The deb is
# downloaded, verified, installed and removed in one layer. apt lists are kept on purpose: with
# install_all_prerequisites, eim may still `sudo apt-get install` anything it finds missing.
ARG EIM_VERSION=0.12.2
ARG EIM_DEB_SHA256=15efb2ddf24cdcc3dfd766fa0cf0b53656137a2dd0f85117c22dbe50afdb1bd1
RUN apt-get update && apt-get install -y ca-certificates curl sudo python3-pip python3-venv && \
    curl -fsSL -o /tmp/eim-cli.deb \
        "https://github.com/espressif/idf-im-ui/releases/download/v${EIM_VERSION}/eim-cli-linux-x64.deb" && \
    echo "${EIM_DEB_SHA256}  /tmp/eim-cli.deb" | sha256sum -c - && \
    apt-get install -y /tmp/eim-cli.deb && \
    rm /tmp/eim-cli.deb && \
    mkdir -p /etc/udev/rules.d/ # eim installs openocd udev rules here, so the directory must exist

ARG JENKINS_UID
RUN groupadd -g ${JENKINS_UID} jenkins && \
    useradd -m -u ${JENKINS_UID} -g jenkins -d /home/jenkins -s /bin/bash jenkins && \
    mkdir -p /home/jenkins/workspace && \
    chown -R jenkins:jenkins /home/jenkins && \
    echo "jenkins ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/jenkins

USER jenkins
WORKDIR /home/jenkins/workspace

COPY ./eim-config.toml ./eim-config.toml
RUN eim install --config eim-config.toml --non-interactive true
RUN eim select v5.1.7

# Hand back to root so the agent image's steps run as root by default, as they did before.
USER root
WORKDIR /
