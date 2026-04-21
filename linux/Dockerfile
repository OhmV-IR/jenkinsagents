FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install docker build tools
RUN apt update
RUN apt install -y ca-certificates curl gnupg lsb-release openjdk-17-jre-headless git sudo
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt update && apt install -y docker-ce docker-ce-cli containerd.io

# Install compilers, vcpkg dependencies, and other tools
RUN apt install -y \
    openssh-client build-essential ninja-build openjdk-21-jre fontconfig \
    zip unzip tar autoconf autoconf-archive automake libtool \
    linux-libc-dev pkg-config software-properties-common \
    nasm bison flex python3 python3.12-venv \
    libx11-dev libxext-dev libxrender-dev libxtst-dev libxrandr-dev \
    libltdl-dev libxi-dev libxcursor-dev libxinerama-dev \
    libgl1-mesa-dev libglu1-mesa-dev libasound2-dev \
    libvulkan-dev libwayland-dev libxkbcommon-dev \
    libssl-dev libbz2-dev liblzma-dev libudev-dev libdrm-dev \
    libglfw3-dev libgtk-3-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev \
    libxcb1-dev libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev \
    libx11-xcb-dev libxkbcommon-x11-dev libegl1-mesa-dev \
    python3.12 python3.12-venv openjdk-21-jdk openjdk-25-jdk openjdk-17-jdk \ 
    '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev \
    libxkbcommon-x11-dev libegl1-mesa-dev
RUN apt install -y clang-tidy clang-tools clang-format codespell

# Install dotnet SDKs
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${PATH}:${DOTNET_ROOT}:${DOTNET_ROOT}/tools"
RUN curl -L -O https://dot.net/v1/dotnet-install.sh
RUN chmod +x dotnet-install.sh
RUN ./dotnet-install.sh --install-dir $DOTNET_ROOT --channel 8.0
RUN ./dotnet-install.sh --install-dir $DOTNET_ROOT --channel 9.0
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

ENV APPIMAGE_EXTRACT_AND_RUN=1
RUN apt install -y libfuse2 file binutils
RUN curl -L -O https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage
RUN chmod +x linuxdeployqt-continuous-x86_64.AppImage
RUN mv linuxdeployqt-continuous-x86_64.AppImage /usr/local/bin/linuxdeployqt

RUN useradd -m -d /home/jenkins -s /bin/bash jenkins && \
    mkdir -p /home/jenkins/workspace && \
    chown -R jenkins:jenkins /home/jenkins

RUN usermod -aG docker jenkins
RUN echo "jenkins ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/jenkins

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="/home/jenkins"

USER jenkins
WORKDIR /home/jenkins/workspace

RUN echo "Beginning prebake of some heavy vcpkg dependencies from a few projects"
RUN echo "Building pragmabackend dependencies"
RUN git clone https://github.com/SpectreRevival/pragmabackend && cd pragmabackend && git submodule update --init --recursive && cmake . --preset x64-debug-linux && cd .. && rm -rf pragmabackend
RUN echo "Building spectrelauncher dependencies"
RUN git clone https://github.com/SpectreRevival/spectrelauncher && cd spectrelauncher && git submodule update --init --recursive && cmake . --preset x64-debug-linux && cd .. && rm -rf spectrelauncher
RUN echo "Finishing building dependencies, now finishing by setting up user..."

ENTRYPOINT ["/bin/bash", "-c", "sudo service docker start && sleep 5 && curl -sO ${JENKINS_URL}/jnlpJars/agent.jar && java -jar agent.jar -url ${JENKINS_URL} -secret ${AGENT_SECRET} -name \"${AGENT_NAME}\" -webSocket -workDir \"${AGENT_WORKDIR}\""]

