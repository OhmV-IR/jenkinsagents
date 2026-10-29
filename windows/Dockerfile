FROM mcr.microsoft.com/windows/server:ltsc2025 AS base

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f

# 1. Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install git (the engine build clones with it). Only what the engine build needs goes in base, as
# any change to base rebuilds every engine; the other tools are installed in the final stage.
RUN choco install -y git
RUN git config --system core.longpaths true

# 3. Install VS 2026 Build Tools (exit code 3010 = installed, reboot required)
RUN mkdir C:\TEMP
COPY .vsconfig C:/TEMP/.vsconfig

RUN curl.exe -fSL --retry 5 -o C:\TEMP\vs_buildtools.exe https://aka.ms/vs/stable/vs_buildtools.exe; \
    if ($LASTEXITCODE -ne 0) { throw ('vs_buildtools download failed, curl exit code ' + $LASTEXITCODE) }; \
    $p = Start-Process -FilePath C:\TEMP\vs_buildtools.exe -Wait -PassThru -ArgumentList @( \
        '--quiet', '--wait', '--norestart', '--nocache', \
        '--installPath', 'C:\BuildTools', \
        '--config', 'C:\TEMP\.vsconfig', \
        '--remove', 'Microsoft.VisualStudio.Component.Windows10SDK.10240', \
        '--remove', 'Microsoft.VisualStudio.Component.Windows10SDK.10586', \
        '--remove', 'Microsoft.VisualStudio.Component.Windows10SDK.14393', \
        '--remove', 'Microsoft.VisualStudio.Component.Windows81SDK'); \
    if ($p.ExitCode -notin 0,3010) { throw ('vs_buildtools.exe failed with exit code ' + $p.ExitCode) }; \
    Remove-Item C:\TEMP\vs_buildtools.exe
# The VS Windows SDK component does not include the SDK's "Debugging Tools for Windows" feature, which is
# the only thing that ships PDBCopy.exe. The installed build's Win64 strip step needs it
# ("Unable to find installed PDBCOPY.EXE, which is required to strip symbols"), so install just that
# feature from the matching standalone SDK installer (10.0.22621.2428).
RUN curl.exe -fsSL --retry 5 -o C:\TEMP\winsdksetup.exe https://go.microsoft.com/fwlink/?linkid=2250105; \
    if ($LASTEXITCODE) { throw 'winsdksetup download failed' }; \
    $p = Start-Process C:\TEMP\winsdksetup.exe -Wait -PassThru -ArgumentList @( \
        '/features', 'OptionId.WindowsDesktopDebuggers', '/quiet', '/norestart', '/ceip', 'off'); \
    if ($p.ExitCode -notin 0, 3010) { throw "winsdksetup.exe exited with $($p.ExitCode); see the logs in $env:TEMP" }; \
    Remove-Item C:\TEMP\winsdksetup.exe; \
    if (-not (Test-Path 'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\PDBCopy.exe')) { throw 'PDBCopy.exe missing after installing Windows SDK debugging tools' }
RUN New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\rc.exe' -Force; New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\rc.exe' -Name 'MitigationOptions' -Value 2 -PropertyType QWord -Force

ENV UE_ROOT="C:\UnrealEngine"

# Basic build dependencies of the agent's jobs; temurin25 is the JDK the agent runs on.
RUN choco install -y cmake ninja curl temurin25 make python312 wget 7zip.install

# Setup Jenkins User
RUN net user jenkins /add /passwordreq:no; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins\AppData\Local\Temp -Force; \
    icacls C:\Users\jenkins /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\TEMP /grant 'jenkins:(OI)(CI)F' /T

# Rust toolchain directories
RUN New-Item -ItemType Directory -Path C:\cargo -Force; \
    New-Item -ItemType Directory -Path C:\rustup -Force; \
    icacls C:\cargo /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\rustup /grant 'jenkins:(OI)(CI)F' /T

ARG EIM_VERSION=0.12.2
ARG EIM_EXE_SHA256=6FE22437B7BAE5A4EF4A8A0490E067CB02896A20EAFBED8AD56A9E8345347F80
RUN New-Item -ItemType Directory -Path C:\eim-cli\bin -Force | Out-Null; \
    curl.exe -fSL --retry 5 -o C:\eim-cli\bin\eim.exe ('https://github.com/espressif/idf-im-ui/releases/download/v' + $env:EIM_VERSION + '/eim-cli-windows-x64.exe'); \
    if ($LASTEXITCODE -ne 0) { throw ('eim download failed, curl exit code ' + $LASTEXITCODE) }; \
    if ((Get-FileHash C:\eim-cli\bin\eim.exe -Algorithm SHA256).Hash -ne $env:EIM_EXE_SHA256) { throw 'eim SHA256 mismatch' }
# C:\Users\jenkins\.dotnet\tools is where `dotnet tool install -g` puts global tools for jenkins.
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\ProgramData\chocolatey\bin;' + 'C:\eim-cli\bin;' + 'C:\cargo\bin;' + 'C:\Users\jenkins\.dotnet\tools;' + $env:Path, [EnvironmentVariableTarget]::Machine)

# Environment Configuration
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup" \
    JENKINS_URL="" \
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins"
ENV USERPROFILE="C:\Users\jenkins" \
    LOCALAPPDATA="C:\Users\jenkins\AppData\Local" \
    APPDATA="C:\Users\jenkins\AppData\Roaming" \
    TEMP="C:\Users\jenkins\AppData\Local\Temp" \
    TMP="C:\Users\jenkins\AppData\Local\Temp" \
    GIT_TERMINAL_PROMPT=0

USER jenkins
WORKDIR C:\\Users\\jenkins

# Install rust: latest rustup-init, verified against the checksum rustup publishes next to it.
# The installer is downloaded and deleted in the same step, so it does not stay in a layer.
RUN $base = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc'; \
    curl.exe -fSL --retry 5 -o C:\TEMP\rustup-init.exe ($base + '/rustup-init.exe'); \
    if ($LASTEXITCODE -ne 0) { throw ('rustup-init.exe download failed, curl exit code ' + $LASTEXITCODE) }; \
    $sha256 = curl.exe -fsSL --retry 5 ($base + '/rustup-init.exe.sha256'); \
    if ($LASTEXITCODE -ne 0) { throw ('rustup-init.exe.sha256 download failed, curl exit code ' + $LASTEXITCODE) }; \
    $expected = (($sha256 -join ' ').Trim() -split '\s+')[0]; \
    if ((Get-FileHash C:\TEMP\rustup-init.exe -Algorithm SHA256).Hash -ne $expected) { throw 'rustup-init.exe SHA256 mismatch' }; \
    C:\TEMP\rustup-init.exe -y --default-toolchain stable --profile minimal --quiet; \
    if ($LASTEXITCODE -ne 0) { throw ('rustup-init failed with exit code ' + $LASTEXITCODE) }; \
    Remove-Item C:\TEMP\rustup-init.exe
# No targets besides the host's (x86_64-pc-windows-msvc): Android targets are built on the Linux agent,
# which has the NDK and is the cheaper runner.
RUN rustup component add rustfmt clippy
RUN cargo install protoc-gen-prost

# In C:\TEMP rather than the agent's work directory (C:\Users\jenkins).
COPY eim-config.toml C:/TEMP/eim-config.toml
RUN eim install --config C:\TEMP\eim-config.toml --non-interactive true
RUN eim select v5.1.7

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="true"
ENV DOTNET_NOLOGO="true"

# Outside C:\Users\jenkins (AGENT_WORKDIR), so a volume mounted there cannot hide it.
COPY jenkins-agent-entrypoint.ps1 C:/ProgramData/Jenkins/jenkins-agent-entrypoint.ps1
ENTRYPOINT ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\ProgramData\\Jenkins\\jenkins-agent-entrypoint.ps1"]
