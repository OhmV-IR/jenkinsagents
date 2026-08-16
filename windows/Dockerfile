FROM mcr.microsoft.com/windows/server:ltsc2025

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f

# 1. Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install basic build dependencies
RUN choco install -y git cmake ninja curl openjdk make python312
RUN git config --system core.longpaths true

# 3. Install VS 2026 Build Tools
RUN mkdir C:\TEMP
COPY .vsconfig C:/TEMP/.vsconfig

SHELL ["cmd", "/S", "/C"]
RUN curl -SL --output C:\TEMP\vs_buildtools.exe https://aka.ms/vs/stable/vs_buildtools.exe ^ \
    && C:\TEMP\vs_buildtools.exe ^ \
        --quiet ^ \
        --wait ^ \
        --norestart ^ \
        --nocache ^ \
        --installPath "C:\BuildTools" ^ \
        --config "C:\TEMP\.vsconfig" ^ \
        --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 ^ \
        --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 ^ \
        --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 ^ \
        --remove Microsoft.VisualStudio.Component.Windows81SDK ^ \
    && del C:\TEMP\vs_buildtools.exe
RUN reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\rc.exe" /v MitigationOptions /t REG_QWORD /d 2 /f
# Verify build tools installation
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]
RUN if (-not (Test-Path 'C:\BuildTools')) { throw 'Build Tools installation failed' }

# Install esp-idf
ADD https://github.com/espressif/idf-im-ui/releases/download/v0.12.2/eim-cli-windows-x64.exe eim-cli/bin/eim.exe
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\eim-cli\bin;' + 'C:\cargo\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)

# 4. Setup Jenkins User
RUN net user jenkins /add /passwordreq:no; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins\AppData\Local\Temp -Force; \
    New-Item -ItemType Directory -Path C:\cargo -Force; \
    New-Item -ItemType Directory -Path C:\rustup -Force; \
    icacls C:\Users\jenkins /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\cargo /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\rustup /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\TEMP /grant 'jenkins:(OI)(CI)F' /T

# 5. Environment Configuration
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup" \
    JENKINS_URL="" \
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins" \
    USERPROFILE="C:\Users\jenkins" \
    LOCALAPPDATA="C:\Users\jenkins\AppData\Local" \
    APPDATA="C:\Users\jenkins\AppData\Roaming" \
    TEMP="C:\Users\jenkins\AppData\Local\Temp" \
    TMP="C:\Users\jenkins\AppData\Local\Temp" \
    GIT_TERMINAL_PROMPT=0

USER jenkins
WORKDIR C:\\Users\\jenkins

COPY eim-config.toml eim-config.toml
RUN eim install --config eim-config.toml --non-interactive true
RUN eim select v5.1.7

# Install rust
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup"

RUN Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "C:\TEMP\rustup-init.exe"; \
    C:\TEMP\rustup-init.exe -y --default-toolchain stable --profile default;
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
