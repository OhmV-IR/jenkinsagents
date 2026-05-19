FROM mcr.microsoft.com/windows/server:ltsc2025

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# 1. Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install basic build dependencies
RUN choco install -y git cmake ninja curl openjdk make python312

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

# Install rust
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup"

RUN Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "C:\TEMP\rustup-init.exe"
RUN C:\TEMP\rustup-init.exe -y --default-toolchain stable --profile default
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\cargo\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)
RUN rustup component add rustfmt clippy
RUN del C:\TEMP\rustup-init.exe

# Install esp-idf
ADD https://github.com/espressif/idf-im-ui/releases/download/v0.12.2/eim-cli-windows-x64.exe eim-cli/bin/eim.exe
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\eim-cli\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)
COPY eim-config.toml eim-config.toml
RUN eim install --config eim-config.toml --non-interactive true
RUN eim select v5.1.7

# 4. Setup Jenkins User
RUN net user jenkins /add /passwordreq:no; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins -Force; \
    icacls C:\\Users\\jenkins /grant 'jenkins:(OI)(CI)F' /T
RUN takeown /f "C:\cargo" /r /d y
RUN icacls "C:\cargo" /grant "jenkins:F" /t
RUN takeown /f "C:\rustup" /r /d y
RUN icacls "C:\rustup" /grant "jenkins:F" /t

# 5. Environment Configuration
ENV JENKINS_URL="" \ 
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins"

USER jenkins
WORKDIR C:\\Users\\jenkins

RUN Set-Content -Path C:\shell.bat -Value '@echo off'; ` \
    Add-Content -Path C:\shell.bat -Value 'call "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64 && %*';
SHELL ["C:\\shell.bat", "cmd", "/S", "/C"]
# to invalidate cache when repo changes
ADD https://api.github.com/repos/SpectreRevival/pragmabackend/git/refs/heads/master version.json
RUN git clone https://github.com/SpectreRevival/pragmabackend && cd pragmabackend && git submodule update --init --recursive && cmake . --preset x64-debug-win && cd .. && rmdir /s /q pragmabackend && if exist C:\\b rmdir /s /q C:\\b && if exist C:\\d rmdir /s /q C:\\d && if exist C:\\p rmdir /s /q C:\\p
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

ENTRYPOINT ["powershell", "-NoLogo", "-Command", \
    "$ErrorActionPreference = 'Stop'; \
    Write-Host 'Fetching agent.jar from' $env:JENKINS_URL; \
    Invoke-WebRequest -UseBasicParsing -Uri \"$($env:JENKINS_URL)/jnlpJars/agent.jar\" -OutFile 'agent.jar'; \
    Write-Host 'Starting Jenkins Agent...'; \
    java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
