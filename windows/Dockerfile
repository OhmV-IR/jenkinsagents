# Base image chain, each built separately and only on purpose so editing this file never re-runs
# their installs: windows/server -> windows-buildtools (choco tools, VS 2026, GDK) -> esp-idf-windows
# (jenkins user, ESP-IDF) -> this image.
ARG ESP_IDF_IMAGE=registry.ohmvir.dev/esp-idf-windows:latest
# Engine image built by unreal/windows/Dockerfile (installed UE build compiled from source). It is
# built separately and only on purpose, because compiling the engine takes many hours. Pulled
# through registry.ohmvir.dev (pushes go to localhost:5000, see the Jenkinsfile).
ARG UE_ENGINE_IMAGE=registry.ohmvir.dev/unreal-engine-windows:5.8.3-release

FROM ${UE_ENGINE_IMAGE} AS unreal-engine

# ---------------------------------------------------------------------------------------------
# Stage: final agent image
# ---------------------------------------------------------------------------------------------
FROM ${ESP_IDF_IMAGE}

# Unreal Engine (Windows host): Win64 x64/arm64/arm64ec game targets, Windows server, OpenXR and
# Microsoft Store (.msixvc via the GDK plug-ins). Android/Linux are deliberately left to Linux.
# Copied first so this ~40GB layer is only rebuilt when the base image chain or the engine changes.
# No ACL changes: jenkins is a local Administrator, and an icacls pass over the engine would
# duplicate every file into a new layer.
COPY --from=unreal-engine C:/UnrealEngine C:/UnrealEngine
ENV UE_ROOT="C:\UnrealEngine"

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Runtime prerequisites Setup.bat/the Launcher normally install (VC++ and DirectX redistributables), needed
# by UnrealEditor-Cmd when cooking.
RUN $p = Start-Process -FilePath C:\UnrealEngine\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -Wait -PassThru; \
    if ($p.ExitCode -notin 0,3010) { throw ('UEPrereqSetup_x64.exe failed with exit code ' + $p.ExitCode) }

# Rust toolchain directories (the jenkins user comes from the ESP-IDF base image)
RUN New-Item -ItemType Directory -Path C:\cargo -Force; \
    New-Item -ItemType Directory -Path C:\rustup -Force; \
    icacls C:\cargo /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\rustup /grant 'jenkins:(OI)(CI)F' /T

# Environment Configuration
# (USERPROFILE, APPDATA, TEMP, ... for jenkins are set in the ESP-IDF base image.)
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup" \
    JENKINS_URL="" \
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins"

USER jenkins
WORKDIR C:\\Users\\jenkins

# Install rust
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup"

RUN Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "C:\TEMP\rustup-init.exe"; \
    C:\TEMP\rustup-init.exe -y --default-toolchain stable --profile minimal --quiet;
RUN rustup component add rustfmt clippy
RUN rustup target add aarch64-linux-android x86_64-pc-windows-gnu x86_64-linux-android aarch64-apple-ios armv7-linux-androideabi i686-linux-android
RUN cargo install protoc-gen-prost
RUN Remove-Item -Path C:\TEMP\rustup-init.exe -Force

ENV GIT_TERMINAL_PROMPT=0
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="true"
ENV DOTNET_NOLOGO="true"
ENTRYPOINT ["powershell", "-NoLogo", "-Command", \
    "$ErrorActionPreference = 'Stop'; \
    Write-Host 'Fetching agent.jar from' $env:JENKINS_URL; \
    Invoke-WebRequest -UseBasicParsing -Uri \"$($env:JENKINS_URL)/jnlpJars/agent.jar\" -OutFile 'agent.jar'; \
    Write-Host 'Starting Jenkins Agent...'; \
    java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
