# syntax=docker/dockerfile:1
# Built from the repository root (shares esp-idf/ with the Windows image):
#   docker build --secret id=github_token,env=GITHUB_TOKEN -f linux/Dockerfile .
FROM cruizba/ubuntu-dind:resolute-latest@sha256:04cd04068660769cb917084850f4ef04988c95aa615be83f09fb16a0c2671c08

ENV DEBIAN_FRONTEND=noninteractive

# Never install recommended/suggested packages, including in apt-get calls made by tools at build time
# (e.g. eim installing prerequisites).
RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' > /etc/apt/apt.conf.d/99no-recommends && \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release git sudo && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip python3 xdg-user-dirs xdg-utils shared-mime-info \
    openjdk-21-jdk-headless \
    libnss3 libnspr4 libxss1 libxcomposite1 libxdamage1 libsm6 libxv1 libfontconfig1 libfreetype6 \
    libglu1-mesa libvulkan1 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 \
    libpango-1.0-0 libpangocairo-1.0-0 libxcursor1 libxi6 libxkbcommon-x11-0 libxrandr2 \
    libxrender1 libxtst6 libx11-xcb1 libgtk-3-0t64 libicu-dev libdrm2 libgbm1 && \
    rm -rf /var/lib/apt/lists/*

# jenkins user with passwordless sudo: the entrypoint starts the inner dockerd with sudo, and eim may
# `sudo apt-get install` prerequisites it finds missing. sudo itself is installed in the first layer.
# Created this early so the toolchains below can be owned by jenkins in the layer that installs them
# (a later chown -R would store a second copy of every file). /opt/UnrealEngine holds the engine
# outside the agent's work directory (/home/jenkins), so a volume mounted there cannot hide it.
ARG UID=1001
ARG GID=1001
RUN test -x /usr/bin/sudo && \
    groupadd -g ${GID} jenkins && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash jenkins && \
    usermod -aG docker jenkins && \
    echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins && \
    chmod 0440 /etc/sudoers.d/jenkins && \
    install -d -o jenkins -g jenkins /opt/UnrealEngine

# JDK 21 is the build JDK (Unreal/Android Gradle, sdkmanager). The Jenkins agent itself runs on JDK 25
# (AGENT_JAVA below).
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    NDKROOT=/opt/android-sdk/ndk/27.2.12479018 \
    NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018 \
    ANDROID_NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018
# The SDK is owned by jenkins so jobs (e.g. Gradle) can install SDK packages they need that are not
# preinstalled here.
ARG ANDROID_CMDLINE_TOOLS_BUILD=15859902
ARG ANDROID_CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583

RUN set -eu; \
    curl -fSL --retry 5 -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"; \
    echo "${ANDROID_CMDLINE_TOOLS_SHA256}  /tmp/cmdline-tools.zip" | sha256sum -c -; \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools; \
    mkdir -p "${ANDROID_HOME}/cmdline-tools"; \
    mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest"; \
    rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip; \
    sdkmanager="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"; \
    yes | "${sdkmanager}" --licenses > /dev/null; \
    "${sdkmanager}" --install \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.1" \
        "ndk;27.2.12479018"; \
    rm -rf /root/.android; \
    chown -R jenkins:jenkins "${ANDROID_HOME}"

RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

USER jenkins
WORKDIR /home/jenkins

ARG UE_GIT_TAG=5.8.3-release
# Extra BuildGraph arguments, e.g. "-set:GameConfigurations=Development;Shipping".
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
# Installed build: Linux x64 + Android target platforms, Server targets.
# Clone, Setup.sh and the build run in one step, and everything but the output (source tree with its
# Setup.sh dependencies, intermediates, NuGet/UBT caches) is deleted in that same step, so neither the
# source nor the ~200GB of build scratch ever becomes part of a layer. *.debug files (split debug info)
# are dropped too; the *.sym files the engine uses for callstacks are kept.
RUN --mount=type=secret,id=github_token,required=true,uid=${UID} \
    --mount=type=cache,id=ue-gitdeps,target=/home/jenkins/.ue-gitdeps,uid=${UID},gid=${GID},sharing=locked \
    set -eu; \
    auth="$(printf 'x-access-token:%s' "$(cat /run/secrets/github_token)" | base64 -w0)"; \
    git -c http.extraHeader="Authorization: Basic ${auth}" \
        clone --depth 1 --branch "${UE_GIT_TAG}" https://github.com/EpicGames/UnrealEngine.git UnrealEngine-src; \
    cd UnrealEngine-src; \
    ./Setup.sh --cache=/home/jenkins/.ue-gitdeps \
        --exclude=Win32 --exclude=Win64 --exclude=Mac; \
    xml=Engine/Build/InstalledEngineBuild.xml; \
    for opt in BuiltDirectory WithDDC WithServer WithClient WithLinux WithLinuxArm64 WithAndroid WithWin64 WithMac WithIOS WithTVOS; do \
        grep -q "Name=\"${opt}\"" "${xml}" || { echo "ERROR: ${xml} in ${UE_GIT_TAG} has no '${opt}' option; update the BuildGraph -set: list" >&2; exit 1; }; \
    done; \
    Engine/Build/BatchFiles/RunUAT.sh BuildGraph -script="${xml}" -target="Make Installed Build Linux" \
        -set:BuiltDirectory=/home/jenkins/LocalBuilds \
        -set:WithDDC=false \
        -set:WithServer=true -set:WithClient=false \
        -set:WithLinux=true -set:WithLinuxArm64=false -set:WithAndroid=true \
        -set:WithWin64=false -set:WithMac=false -set:WithIOS=false -set:WithTVOS=false \
        ${UE_BUILDGRAPH_EXTRA_ARGS}; \
    test -f /home/jenkins/LocalBuilds/Linux/Engine/Build/Build.version; \
    find /home/jenkins/LocalBuilds/Linux -name '*.debug' -type f -delete; \
    mv /home/jenkins/LocalBuilds/Linux "/opt/UnrealEngine/${UE_GIT_TAG}"; \
    cd /home/jenkins; \
    rm -rf UnrealEngine-src LocalBuilds .nuget .config/Epic .local/share/Epic
ENV UE_ROOT=/opt/UnrealEngine/${UE_GIT_TAG}

USER root

# Install extra dependencies and other tools for vcpkg .etc
# java/javac on PATH are pinned to JDK 21 so they match JAVA_HOME.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client ninja-build fontconfig \
    zip unzip tar autoconf autoconf-archive automake libtool \
    linux-libc-dev pkg-config software-properties-common \
    nasm bison flex \
    libx11-dev libxext-dev libxrender-dev libxtst-dev libxrandr-dev \
    libltdl-dev libxi-dev libxcursor-dev libxinerama-dev \
    libgl1-mesa-dev libglu1-mesa-dev libasound2-dev \
    libvulkan-dev libwayland-dev libxkbcommon-dev \
    libssl-dev libbz2-dev liblzma-dev libudev-dev libdrm-dev \
    libglfw3-dev libgtk-3-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev \
    libxcb1-dev libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev \
    libx11-xcb-dev libxkbcommon-x11-dev libegl1-mesa-dev \
    python3 python3-venv openjdk-21-jdk openjdk-25-jdk openjdk-17-jdk \
    '^libxcb.*-dev' \
    libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev \
    xdg-utils patchelf libmosquitto-dev && \
    update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java && \
    update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac && \
    rm -rf /var/lib/apt/lists/*

# apt lists are kept on purpose here: with install_all_prerequisites, eim may still
# `sudo apt-get install` anything it finds missing.
ARG EIM_VERSION=0.12.2
ARG EIM_DEB_SHA256=15efb2ddf24cdcc3dfd766fa0cf0b53656137a2dd0f85117c22dbe50afdb1bd1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl sudo python3-pip python3-venv && \
    curl -fsSL -o /tmp/eim-cli.deb \
        "https://github.com/espressif/idf-im-ui/releases/download/v${EIM_VERSION}/eim-cli-linux-x64.deb" && \
    echo "${EIM_DEB_SHA256}  /tmp/eim-cli.deb" | sha256sum -c - && \
    apt-get install -y --no-install-recommends /tmp/eim-cli.deb && \
    rm /tmp/eim-cli.deb && \
    mkdir -p /etc/udev/rules.d/ # eim installs openocd udev rules here, so the directory must exist

USER jenkins
WORKDIR /home/jenkins

# The config is bind-mounted for this step only, so it never lands in a layer or the agent's directories.
RUN --mount=type=bind,source=esp-idf/eim-config.toml,target=/tmp/eim-config.toml \
    eim install --config /tmp/eim-config.toml --non-interactive true
RUN eim select v5.1.7

USER root
ENV RUSTUP_HOME="/rustup"
ENV CARGO_HOME="/cargo"
ENV PATH="/cargo/bin:${PATH}"
# The toolchains are installed as (and owned by) jenkins.
RUN install -d -o jenkins -g jenkins "${RUSTUP_HOME}" "${CARGO_HOME}"

USER jenkins
# Latest rustup-init, verified against the checksum rustup publishes next to it.
RUN set -eu; \
    base=https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu; \
    curl -fSL --proto '=https' --tlsv1.2 --retry 5 -o /tmp/rustup-init "${base}/rustup-init"; \
    sha256="$(curl -fsSL --proto '=https' --tlsv1.2 --retry 5 "${base}/rustup-init.sha256" | cut -d' ' -f1)"; \
    echo "${sha256}  /tmp/rustup-init" | sha256sum -c -; \
    chmod +x /tmp/rustup-init; \
    /tmp/rustup-init -y; \
    rm /tmp/rustup-init
RUN rustup component add rustfmt clippy
# Android targets live here (this image has the NDK); Windows targets are built on the Windows agent.
RUN rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi i686-linux-android
RUN cargo install protoc-gen-prost

USER root
WORKDIR /

RUN apt-get update && apt-get install -y --no-install-recommends clang-tidy clang-tools clang-format codespell cppcheck sqlfluff && \
    rm -rf /var/lib/apt/lists/*

# Install the latest .NET SDK of the DOTNET_CHANNEL major version. Its tarball URL and SHA512 come from
# the channel's release metadata, and the download is verified against that hash.
# `dotnet tool install -g` puts global tools in ~/.dotnet/tools of the user running it (jenkins).
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${PATH}:${DOTNET_ROOT}:/home/jenkins/.dotnet/tools"
ARG DOTNET_CHANNEL=10.0
RUN set -eu; \
    curl -fsSL --retry 5 -o /tmp/dotnet-releases.json \
        "https://builds.dotnet.microsoft.com/dotnet/release-metadata/${DOTNET_CHANNEL}/releases.json"; \
    set -- $(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); v = d["latest-sdk"]; s = next(s for r in d["releases"] for s in r.get("sdks", []) + [r.get("sdk") or {}] if s.get("version") == v); f = next(f for f in s["files"] if f["rid"] == "linux-x64" and f["name"].endswith(".tar.gz")); print(f["url"], f["hash"])' /tmp/dotnet-releases.json); \
    [ $# -eq 2 ] || { echo "ERROR: could not find the latest .NET ${DOTNET_CHANNEL} SDK tarball in releases.json" >&2; exit 1; }; \
    echo "Installing .NET SDK from $1"; \
    curl -fSL --retry 5 -o /tmp/dotnet-sdk.tar.gz "$1"; \
    echo "$2  /tmp/dotnet-sdk.tar.gz" | sha512sum -c -; \
    mkdir -p "${DOTNET_ROOT}"; \
    tar -xzf /tmp/dotnet-sdk.tar.gz -C "${DOTNET_ROOT}"; \
    rm /tmp/dotnet-sdk.tar.gz /tmp/dotnet-releases.json

# Setup GitHub CLI repository
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Clean update and install
RUN apt-get update && apt-get install -y --no-install-recommends gh && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc \
    -o /usr/share/keyrings/kitware-archive-keyring.asc && \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.asc] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && apt-get install -y --no-install-recommends cmake && rm -rf /var/lib/apt/lists/*

# Latest buf release, verified against the release's sha256.txt. The build fails if the latest release
# is a new major version, so a major upgrade is a deliberate BUF_MAJOR bump.
ARG BUF_MAJOR=1
RUN set -eu; \
    base=https://github.com/bufbuild/buf/releases/latest/download; \
    cd /tmp; \
    curl -fSLO --retry 5 "${base}/buf-Linux-x86_64"; \
    curl -fsSL --retry 5 "${base}/sha256.txt" | grep ' buf-Linux-x86_64$' | sha256sum -c -; \
    install -m 0755 buf-Linux-x86_64 /usr/local/bin/buf; \
    rm buf-Linux-x86_64; \
    version="$(buf --version)"; \
    case "${version}" in "${BUF_MAJOR}".*) ;; *) echo "ERROR: latest buf is ${version}, expected ${BUF_MAJOR}.x; bump BUF_MAJOR" >&2; exit 1 ;; esac

RUN apt-get update && apt-get install -y --no-install-recommends util-linux-extra vim ncdu && rm -rf /var/lib/apt/lists/*

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="/home/jenkins"
# JVM the agent runs on.
ENV AGENT_JAVA="/usr/lib/jvm/java-25-openjdk-amd64/bin/java"
# 1 = start the inner dockerd (docker-in-docker); the ndind image sets 0 and uses the host's daemon.
ENV START_DOCKERD="1"

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="true"
ENV DOTNET_NOLOGO="true"

# Outside /home/jenkins (AGENT_WORKDIR), so a volume mounted there cannot hide it.
COPY --chmod=0755 linux/jenkins-agent-entrypoint.sh /usr/local/bin/jenkins-agent-entrypoint.sh

USER jenkins
WORKDIR /home/jenkins
ENTRYPOINT ["/usr/local/bin/jenkins-agent-entrypoint.sh"]
