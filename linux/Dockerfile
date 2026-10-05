# syntax=docker/dockerfile:1
# Unreal Engine version baked into the agent. Bump together with UE_ARCHIVE_URL / UE_ARCHIVE_SHA256.
ARG UE_VERSION=5.8.3
# Fixed uid/gid of the jenkins user so the engine layer can be copied with --link (see below).
ARG JENKINS_UID=1001

# ---------------------------------------------------------------------------------------------
# Stage: unreal-engine
# Downloads and extracts Epic's prebuilt Linux engine (Linux_Unreal_Engine_<ver>.zip from
# https://www.unrealengine.com/linux). Epic only serves it behind an account login, so it has to
# be mirrored somewhere this build can reach; pass that location with --build-arg UE_ARCHIVE_URL.
# Living in its own stage means the ~25GB download/extract is cached independently of the agent
# image, and the build arg (which may carry credentials) never ends up in the final image history.
# ---------------------------------------------------------------------------------------------
FROM cruizba/ubuntu-dind:resolute-latest@sha256:04cd04068660769cb917084850f4ef04988c95aa615be83f09fb16a0c2671c08 AS unreal-engine

ARG UE_VERSION
ARG UE_ARCHIVE_URL
# Optional but recommended: sha256 of the archive, verified before extraction.
ARG UE_ARCHIVE_SHA256=""

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Download, verify, extract and delete the archive in a single layer so the zip is never stored.
RUN set -eu; \
    if [ -z "${UE_ARCHIVE_URL:-}" ]; then \
        echo "ERROR: --build-arg UE_ARCHIVE_URL=<url of Linux_Unreal_Engine_${UE_VERSION}.zip> is required" >&2; exit 1; \
    fi; \
    curl -fSL --retry 5 --retry-delay 10 -o /tmp/ue.zip "${UE_ARCHIVE_URL}"; \
    if [ -n "${UE_ARCHIVE_SHA256}" ]; then echo "${UE_ARCHIVE_SHA256}  /tmp/ue.zip" | sha256sum -c -; fi; \
    mkdir -p /tmp/ue; \
    unzip -q /tmp/ue.zip -d /tmp/ue; \
    rm -f /tmp/ue.zip; \
    # The engine root is the folder holding Engine/ (the zip may or may not wrap it in a folder).
    version_file="$(find /tmp/ue -maxdepth 4 -path '*/Engine/Build/Build.version' -print -quit)"; \
    [ -n "${version_file}" ] || { echo "ERROR: archive does not contain Engine/Build/Build.version" >&2; exit 1; }; \
    mv "$(dirname "$(dirname "$(dirname "${version_file}")")")" /opt/UnrealEngine; \
    rm -rf /tmp/ue; \
    found="$(sed -n 's/.*"\(Major\|Minor\|Patch\)Version": *\([0-9][0-9]*\).*/\2/p' /opt/UnrealEngine/Engine/Build/Build.version | paste -sd.)"; \
    [ "${found}" = "${UE_VERSION}" ] || { echo "ERROR: archive contains UE ${found}, expected ${UE_VERSION}" >&2; exit 1; }; \
    # Make sure the UBT/UAT entry scripts are executable even if the archive lost unix modes.
    find /opt/UnrealEngine/Engine/Build/BatchFiles -name '*.sh' -exec chmod 0755 {} +

# ---------------------------------------------------------------------------------------------
# Stage: final agent image
# ---------------------------------------------------------------------------------------------
FROM cruizba/ubuntu-dind:resolute-latest@sha256:04cd04068660769cb917084850f4ef04988c95aa615be83f09fb16a0c2671c08

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y ca-certificates curl gnupg lsb-release openjdk-17-jre-headless git sudo

# Install compilers, vcpkg dependencies, and other tools
RUN apt update && apt install -y \
    openssh-client build-essential ninja-build openjdk-21-jre fontconfig \
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
    xdg-utils patchelf libmosquitto-dev

ADD https://github.com/espressif/idf-im-ui/releases/download/v0.12.2/eim-cli-linux-x64.deb eim-cli.deb
RUN apt install -y ./eim-cli.deb
RUN rm eim-cli.deb
RUN apt install -y python3-pip
RUN mkdir -p /etc/udev/rules.d/ # it tries to install smth here so must create dir to not fail build

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

ARG JENKINS_UID
RUN groupadd -g ${JENKINS_UID} jenkins && \
    useradd -m -u ${JENKINS_UID} -g jenkins -d /home/jenkins -s /bin/bash jenkins && \
    mkdir -p /home/jenkins/workspace && \
    chown -R jenkins:jenkins /home/jenkins

RUN usermod -aG docker jenkins
RUN apt install -y util-linux-extra
RUN echo "jenkins ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/jenkins

RUN mkdir -p /cargo
RUN mkdir -p /rustup
RUN chown jenkins:jenkins /cargo
RUN chown jenkins:jenkins /rustup
RUN chmod 755 /cargo
RUN chmod 755 /rustup

# ---------------------------------------------------------------------------------------------
# Unreal Engine (Linux host). Covers Linux x64 and Android/Meta Quest (+ OpenXR) targets.
# Windows targets are covered by the Windows agent, see windows/Dockerfile.
# ---------------------------------------------------------------------------------------------
# Shared libraries the editor/commandlet (UnrealEditor-Cmd, used for cooking) loads at runtime
# that are not already pulled in by the -dev packages above.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libnspr4 libxss1 libxcomposite1 libxdamage1 libsm6 libxv1 \
    libfontconfig1 libfreetype6 libglu1-mesa libvulkan1 xdg-user-dirs && \
    rm -rf /var/lib/apt/lists/*

# --link makes this ~45GB layer independent of every layer above it, so editing anything earlier
# in this file neither re-copies it nor changes its digest (no re-push/re-pull of the engine).
# --link cannot resolve user names, hence the pinned numeric JENKINS_UID. The engine is owned by
# jenkins because UBT/UAT write logs and intermediates under Engine/ in some workflows.
COPY --link --from=unreal-engine --chown=${JENKINS_UID}:${JENKINS_UID} /opt/UnrealEngine /opt/UnrealEngine
ENV UE_ROOT=/opt/UnrealEngine

# Android toolchain for UE 5.8 (Android + Meta Quest): NDK r27c, build-tools 35.0.1, SDK platform 35,
# JDK 21. Installed only on Linux; the Windows agent deliberately has no Android support.
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    NDKROOT=/opt/android-sdk/ndk/27.2.12479018 \
    NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018 \
    ANDROID_NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"
# Owned by jenkins so Gradle can auto-install any extra SDK package a project asks for.
RUN install -d -o jenkins -g jenkins -m 0755 ${ANDROID_HOME}

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="/home/jenkins"

USER jenkins
WORKDIR /home/jenkins/workspace

# Installed as jenkins (not root + chown) so the SDK is not duplicated into a second layer.
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
    yes | sdkmanager --licenses > /dev/null; \
    sdkmanager --install \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.1" \
        "ndk;27.2.12479018"; \
    rm -rf "${HOME}/.android/cache"

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

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OUTPUT="true"
ENV DOTNET_NOLOGO="true"

COPY --chmod=0755 jenkins-agent-entrypoint.sh /home/jenkins/jenkins-agent-entrypoint.sh
ENTRYPOINT ["/home/jenkins/jenkins-agent-entrypoint.sh"]
