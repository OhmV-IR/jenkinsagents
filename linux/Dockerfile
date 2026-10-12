# syntax=docker/dockerfile:1
FROM cruizba/ubuntu-dind:resolute-latest@sha256:04cd04068660769cb917084850f4ef04988c95aa615be83f09fb16a0c2671c08

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y ca-certificates curl gnupg lsb-release openjdk-17-jre-headless git sudo

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip python3 xdg-user-dirs xdg-utils shared-mime-info \
    openjdk-21-jdk-headless \
    libnss3 libnspr4 libxss1 libxcomposite1 libxdamage1 libsm6 libxv1 libfontconfig1 libfreetype6 \
    libglu1-mesa libvulkan1 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 \
    libpango-1.0-0 libpangocairo-1.0-0 libxcursor1 libxi6 libxkbcommon-x11-0 libxrandr2 \
    libxrender1 libxtst6 libx11-xcb1 libgtk-3-0t64 libicu-dev libdrm2 libgbm1 && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    NDKROOT=/opt/android-sdk/ndk/27.2.12479018 \
    NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018 \
    ANDROID_NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018
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
    rm -rf /root/.android

RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

USER jenkins

ARG UE_GIT_TAG=5.8.3-release
RUN --mount=type=secret,id=github_token,required=true,uid=1000 \
    set -eu; \
    auth="$(printf 'x-access-token:%s' "$(cat /run/secrets/github_token)" | base64 -w0)"; \
    git -c http.extraHeader="Authorization: Basic ${auth}" \
        clone --depth 1 --branch "${UE_GIT_TAG}" https://github.com/EpicGames/UnrealEngine.git UnrealEngine

RUN --mount=type=cache,id=ue-gitdeps,target=/home/ubuntu/.ue-gitdeps,uid=1000,gid=1000,sharing=locked \
    cd UnrealEngine && \
    ./Setup.sh --cache=/home/ubuntu/.ue-gitdeps \
        --exclude=Win32 --exclude=Win64 --exclude=Mac

# Extra BuildGraph arguments, e.g. "-set:GameConfigurations=Development;Shipping".
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
# Installed build: Linux x64 + Android target platforms, Server targets.
# The output is kept and everything else (source tree, intermediates, NuGet/UBT caches) is deleted
# in the same step, so the ~200GB of build scratch never becomes part of a layer. *.debug files
# (split debug info) are dropped too; the *.sym files the engine uses for callstacks are kept.
RUN set -eu; \
    cd UnrealEngine; \
    xml=Engine/Build/InstalledEngineBuild.xml; \
    for opt in BuiltDirectory WithDDC WithServer WithClient WithLinux WithLinuxArm64 WithAndroid WithWin64 WithMac WithIOS WithTVOS; do \
        grep -q "Name=\"${opt}\"" "${xml}" || { echo "ERROR: ${xml} in ${UE_GIT_TAG} has no '${opt}' option; update the BuildGraph -set: list" >&2; exit 1; }; \
    done; \
    Engine/Build/BatchFiles/RunUAT.sh BuildGraph -script="${xml}" -target="Make Installed Build Linux" \
        -set:BuiltDirectory=/home/jenkins/UnrealEngine/${UE_GIT_TAG} \
        -set:WithDDC=false \
        -set:WithServer=true -set:WithClient=false \
        -set:WithLinux=true -set:WithLinuxArm64=false -set:WithAndroid=true \
        -set:WithWin64=false -set:WithMac=false -set:WithIOS=false -set:WithTVOS=false \
        ${UE_BUILDGRAPH_EXTRA_ARGS}; \
    test -f /home/ubuntu/LocalBuilds/Linux/Engine/Build/Build.version; \
    find /home/ubuntu/LocalBuilds/Linux -name '*.debug' -type f -delete; \
    cd /home/ubuntu; \
    rm -rf UnrealEngine .nuget .config/Epic .local/share/Epic
ENV UE_ROOT=/home/jenkins/UnrealEngine/${UE_GIT_TAG}

USER root

# Install extra dependencies and other tools for vcpkg .etc
RUN apt update && apt install -y \
    openssh-client ninja-build openjdk-21-jre fontconfig \
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
    '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev \
    libxkbcommon-x11-dev libegl1-mesa-dev libgtk-3-dev libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev \
    xdg-utils patchelf libmosquitto-dev && \
    rm -rf /var/lib/apt/lists/*

USER jenkins
WORKDIR /home/jenkins/workspace

ARG EIM_VERSION=0.12.2
ARG EIM_DEB_SHA256=15efb2ddf24cdcc3dfd766fa0cf0b53656137a2dd0f85117c22dbe50afdb1bd1
RUN apt-get update && apt-get install -y ca-certificates curl sudo python3-pip python3-venv && \
    curl -fsSL -o /tmp/eim-cli.deb \
        "https://github.com/espressif/idf-im-ui/releases/download/v${EIM_VERSION}/eim-cli-linux-x64.deb" && \
    echo "${EIM_DEB_SHA256}  /tmp/eim-cli.deb" | sha256sum -c - && \
    apt-get install -y /tmp/eim-cli.deb && \
    rm /tmp/eim-cli.deb && \
    mkdir -p /etc/udev/rules.d/ # eim installs openocd udev rules here, so the directory must exist

COPY ./eim-config.toml ./eim-config.toml
RUN eim install --config eim-config.toml --non-interactive true
RUN eim select v5.1.7

ENV RUSTUP_HOME="/rustup"
ENV CARGO_HOME="/cargo"
ENV PATH="/cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN rustup component add rustfmt clippy
RUN rustup target add aarch64-linux-android
RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add x86_64-linux-android
RUN rustup target add aarch64-apple-ios
RUN rustup target add armv7-linux-androideabi
RUN rustup target add i686-linux-android
RUN cargo install protoc-gen-prost

USER root
WORKDIR /

RUN apt install -y clang-tidy clang-tools clang-format codespell cppcheck sqlfluff

# Install dotnet SDKs
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${PATH}:${DOTNET_ROOT}:${DOTNET_ROOT}/tools"
RUN curl -L -O https://dot.net/v1/dotnet-install.sh
RUN chmod +x dotnet-install.sh
RUN ./dotnet-install.sh --install-dir $DOTNET_ROOT --channel 10.0

# Setup GitHub CLI repository
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Clean update and install
RUN apt-get update && apt-get install -y gh

RUN curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc \
    -o /usr/share/keyrings/kitware-archive-keyring.asc && \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.asc] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && apt-get install -y cmake

RUN curl -fsSL "https://github.com/bufbuild/buf/releases/download/v1.30.0/buf-$(uname -s)-$(uname -m)" -o /usr/local/bin/buf
RUN chmod +x /usr/local/bin/buf

RUN usermod -aG docker jenkins
RUN apt install -y util-linux-extra vim ncdu

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="/home/jenkins"

USER jenkins
WORKDIR /home/jenkins/workspace

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OUTPUT="true"
ENV DOTNET_NOLOGO="true"

COPY --chmod=0755 jenkins-agent-entrypoint.sh /home/jenkins/jenkins-agent-entrypoint.sh
ENTRYPOINT ["/home/jenkins/jenkins-agent-entrypoint.sh"]
