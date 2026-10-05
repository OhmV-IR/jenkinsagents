# syntax=docker/dockerfile:1
# Unreal Engine installed build for the Linux agent, compiled from Epic's GitHub source.
#
# Produces a data-only image (FROM scratch) holding /opt/UnrealEngine and the matching
# /opt/android-sdk. jenkins-agent-linux copies both out of it. The engine build takes hours, so
# this image is only rebuilt on purpose (BUILD_UNREAL_ENGINE in the Jenkinsfile).
#
#   docker build --secret id=github_token,env=GITHUB_TOKEN --build-arg UE_GIT_TAG=5.8.3-release \
#       -t localhost:5000/unreal-engine-linux:5.8.3-release unreal/linux
#
# GITHUB_TOKEN must belong to a GitHub account linked to an Epic account (access to EpicGames/UnrealEngine).

# Git tag of EpicGames/UnrealEngine to build.
ARG UE_GIT_TAG=5.8.3-release

FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Build tools, JDK 21 for the Android build, and the shared libraries UnrealEditor-Cmd needs to
# run headless while the build generates the engine/template DDC.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip python3 xdg-user-dirs xdg-utils shared-mime-info \
    openjdk-21-jdk-headless \
    libnss3 libnspr4 libxss1 libxcomposite1 libxdamage1 libsm6 libxv1 libfontconfig1 libfreetype6 \
    libglu1-mesa libvulkan1 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcairo2 \
    libpango-1.0-0 libpangocairo-1.0-0 libxcursor1 libxi6 libxkbcommon-x11-0 libxrandr2 \
    libxrender1 libxtst6 libx11-xcb1 libgtk-3-0t64 libicu-dev && \
    rm -rf /var/lib/apt/lists/*

# Android toolchain required by UE 5.8 (NDK r27c, build-tools 35.0.1, platform 35, JDK 21). The
# engine's Android libraries are compiled against it here, and the agent copies the same SDK, so
# the two can never drift apart.
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

# UnrealEditor refuses to run as root (and the DDC step runs it), so build as the image's
# unprivileged 'ubuntu' user. File ownership is irrelevant here: the agent re-owns on copy.
USER ubuntu
WORKDIR /home/ubuntu

ARG UE_GIT_TAG
# Shallow clone of just the tag. The token is read from a BuildKit secret and passed as a one-off
# header, so it is never written to .git/config, a layer, or the image history.
RUN --mount=type=secret,id=github_token,required=true,uid=1000 \
    set -eu; \
    auth="$(printf 'x-access-token:%s' "$(cat /run/secrets/github_token)" | base64 -w0)"; \
    git -c http.extraHeader="Authorization: Basic ${auth}" \
        clone --depth 1 --branch "${UE_GIT_TAG}" https://github.com/EpicGames/UnrealEngine.git UnrealEngine

# Binary dependencies (~20GB+). The persistent BuildKit cache keeps the downloaded packs, so moving
# to a new UE tag only downloads what changed. Platforms built nowhere on this host are skipped.
RUN --mount=type=cache,id=ue-gitdeps,target=/home/ubuntu/.ue-gitdeps,uid=1000,gid=1000,sharing=locked \
    cd UnrealEngine && \
    ./Setup.sh --cache=/home/ubuntu/.ue-gitdeps \
        --exclude=Win32 --exclude=Win64 --exclude=Mac --exclude=IOS --exclude=TVOS

# Extra BuildGraph arguments, e.g. "-set:GameConfigurations=Development;Shipping".
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
# Installed build: Linux x64 + Android target platforms, Server targets, editor/template DDC.
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
        -set:BuiltDirectory=/home/ubuntu/LocalBuilds \
        -set:WithDDC=true \
        -set:WithServer=true -set:WithClient=false \
        -set:WithLinux=true -set:WithLinuxArm64=false -set:WithAndroid=true \
        -set:WithWin64=false -set:WithMac=false -set:WithIOS=false -set:WithTVOS=false \
        ${UE_BUILDGRAPH_EXTRA_ARGS}; \
    test -f /home/ubuntu/LocalBuilds/Linux/Engine/Build/Build.version; \
    find /home/ubuntu/LocalBuilds/Linux -name '*.debug' -type f -delete; \
    cd /home/ubuntu; \
    rm -rf UnrealEngine .nuget .config/Epic .local/share/Epic

# ---------------------------------------------------------------------------------------------
# Data-only result image. Each directory is its own layer so they are pushed/pulled in parallel.
# ---------------------------------------------------------------------------------------------
FROM scratch
ARG UE_GIT_TAG
LABEL org.opencontainers.image.title="unreal-engine-linux" \
      org.opencontainers.image.version="${UE_GIT_TAG}"
COPY --from=builder /opt/android-sdk /opt/android-sdk
COPY --from=builder /home/ubuntu/LocalBuilds/Linux /opt/UnrealEngine
