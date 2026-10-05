# syntax=docker/dockerfile:1
# Engine image built by unreal/linux/Dockerfile (installed UE build + matching Android SDK). It is
# built separately and only on purpose, because compiling the engine takes hours. Pulled through
# registry.ohmvir.dev (pushes go to localhost:5000, see the Jenkinsfile).
ARG UE_ENGINE_IMAGE=registry.ohmvir.dev/unreal-engine-linux:5.8.3-release
# Fixed uid/gid of the jenkins user so the engine layers can be copied with --link (see below).
ARG JENKINS_UID=1001

FROM ${UE_ENGINE_IMAGE} AS unreal-engine

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
# Unreal Engine (Linux host). Covers Linux x64, Linux server, and Android/Meta Quest (+ OpenXR).
# Windows targets are covered by the Windows agent, see windows/Dockerfile.
# ---------------------------------------------------------------------------------------------
# Shared libraries the editor/commandlet (UnrealEditor-Cmd, used for cooking) loads at runtime
# that are not already pulled in by the -dev packages above.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 libnspr4 libxss1 libxcomposite1 libxdamage1 libsm6 libxv1 \
    libfontconfig1 libfreetype6 libglu1-mesa libvulkan1 xdg-user-dirs && \
    rm -rf /var/lib/apt/lists/*

# --link makes these large layers independent of every layer above them, so editing anything
# earlier in this file neither re-copies them nor changes their digests (no re-push/re-pull).
# --link cannot resolve user names, hence the pinned numeric JENKINS_UID. Both trees are owned by
# jenkins: UBT/UAT write under Engine/ in some workflows, and Gradle may install extra SDK packages.
COPY --link --from=unreal-engine --chown=${JENKINS_UID}:${JENKINS_UID} /opt/UnrealEngine /opt/UnrealEngine
COPY --link --from=unreal-engine --chown=${JENKINS_UID}:${JENKINS_UID} /opt/android-sdk /opt/android-sdk
ENV UE_ROOT=/opt/UnrealEngine

# Android toolchain for UE 5.8 (Android + Meta Quest), the same SDK the engine was compiled with:
# NDK r27c, build-tools 35.0.1, SDK platform 35, JDK 21. Linux only; Windows has no Android support.
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    NDKROOT=/opt/android-sdk/ndk/27.2.12479018 \
    NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018 \
    ANDROID_NDK_ROOT=/opt/android-sdk/ndk/27.2.12479018
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="/home/jenkins"

USER jenkins
WORKDIR /home/jenkins/workspace

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
