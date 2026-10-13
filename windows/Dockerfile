# Built from the repository root (shares esp-idf/ with the Linux image):
#   docker build --build-arg GITHUB_TOKEN --target ue-builder -t jenkins-agent-windows-ue-builder:latest -f windows/Dockerfile .
#   docker build --build-arg GITHUB_TOKEN -t jenkins-agent-windows:latest -f windows/Dockerfile .
#
# The Windows (classic) builder has no build secrets, so GITHUB_TOKEN is a build arg, and build arg
# values are recorded in the history of every later RUN of their stage (`docker history`). Only the
# ue-builder stage declares it; the final image starts from base and copies just the installed engine
# out of ue-builder, so the token is not in anything that gets pushed. ue-builder stays local and is
# tagged (first command above) so `docker image prune` does not delete it as dangling, which would
# throw away the engine build cache.
FROM mcr.microsoft.com/windows/server:ltsc2025 AS base

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f

# 1. Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install basic build dependencies
RUN choco install -y git cmake ninja curl temurin25 make python312
RUN git config --system core.longpaths true

# 3. Install VS 2026 Build Tools (exit code 3010 = installed, reboot required)
RUN mkdir C:\TEMP
COPY windows/.vsconfig C:/TEMP/.vsconfig

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
RUN reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\rc.exe" /v MitigationOptions /t REG_QWORD /d 2 /f

# Builds the engine. Local only: never pushed (see the top of this file).
FROM base AS ue-builder
ARG UE_GIT_TAG=5.8.3-release
ARG GITHUB_TOKEN
# Extra BuildGraph arguments, e.g. -set:GameConfigurations=Development;Shipping
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
# Installed build: Win64 target platform (plus ARM64 if this engine version has an installed-build
# option for it), Server targets, no DDC.
# Clone, Setup.bat and the build run in one step, and everything but the output (source tree with its
# Setup.bat dependencies, intermediates, local caches) is deleted in that same step, so neither the
# source nor the build scratch ever becomes part of a layer. The token is sent as a one-off header, so
# it is not written to .git/config. Setup.bat also installs the engine prerequisites (UEPrereqSetup_x64.exe)
# into this stage, which the build needs; platforms this host never builds are skipped (Android/Linux live
# on the Linux agent). *.pdb files are dropped as the Launcher build does (they are only needed to debug
# the engine itself).
RUN if (-not $env:GITHUB_TOKEN) { throw 'GITHUB_TOKEN build arg is required (GitHub account with access to EpicGames/UnrealEngine)' }; \
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $env:GITHUB_TOKEN)); \
    & 'C:\Program Files\Git\cmd\git.exe' -c core.longpaths=true -c ('http.extraHeader=Authorization: Basic ' + $auth) \
        clone --depth 1 --branch $env:UE_GIT_TAG https://github.com/EpicGames/UnrealEngine.git C:\UE; \
    if ($LASTEXITCODE -ne 0) { throw ('git clone failed with exit code ' + $LASTEXITCODE) }; \
    Set-Location C:\UE; \
    & cmd /c Setup.bat --exclude=Android --exclude=Linux --exclude=LinuxArm64 --exclude=Mac --exclude=IOS --exclude=TVOS; \
    if ($LASTEXITCODE -ne 0) { throw ('Setup.bat failed with exit code ' + $LASTEXITCODE) }; \
    $xml = Get-Content Engine\Build\InstalledEngineBuild.xml -Raw; \
    foreach ($opt in 'BuiltDirectory','WithDDC','WithServer','WithClient','WithWin64','WithLinux','WithLinuxArm64','WithAndroid','WithMac','WithIOS','WithTVOS') { \
        if ($xml -notmatch ('<Option\s+Name=.' + $opt + '.')) { throw ('InstalledEngineBuild.xml in ' + $env:UE_GIT_TAG + ' has no ' + $opt + ' option; update the BuildGraph -set: list') } \
    }; \
    $armOptions = @([regex]::Matches($xml, '<Option\s+Name=.(With\w*Win\w*Arm64\w*).') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique); \
    if ($armOptions) { Write-Host ('Enabling Windows ARM64 options: ' + ($armOptions -join ', ')) } \
    else { Write-Warning ('No Windows ARM64 installed-build option found for ' + $env:UE_GIT_TAG + ', so the build only contains x64 Win64 binaries. If it is named differently, pass it via UE_BUILDGRAPH_EXTRA_ARGS.') }; \
    $setArgs = @('-set:BuiltDirectory=C:\LocalBuilds', '-set:WithDDC=false', '-set:WithServer=true', '-set:WithClient=false', \
        '-set:WithWin64=true', '-set:WithLinux=false', '-set:WithLinuxArm64=false', '-set:WithAndroid=false', \
        '-set:WithMac=false', '-set:WithIOS=false', '-set:WithTVOS=false') + \
        @($armOptions | ForEach-Object { '-set:' + $_ + '=true' }) + \
        @($env:UE_BUILDGRAPH_EXTRA_ARGS -split ' ' | Where-Object { $_ }); \
    & .\Engine\Build\BatchFiles\RunUAT.bat BuildGraph '-script=Engine/Build/InstalledEngineBuild.xml' '-target=Make Installed Build Win64' @setArgs; \
    if ($LASTEXITCODE -ne 0) { throw ('BuildGraph failed with exit code ' + $LASTEXITCODE) }; \
    if (-not (Test-Path C:\LocalBuilds\Windows\Engine\Build\Build.version)) { throw 'Installed build not found in C:\LocalBuilds\Windows' }; \
    Get-ChildItem C:\LocalBuilds\Windows -Recurse -Filter *.pdb -File | Remove-Item -Force -ErrorAction Continue; \
    Move-Item C:\LocalBuilds\Windows C:\UnrealEngine; \
    Set-Location C:\; \
    cmd /c rmdir /s /q \\?\C:\UE; \
    Remove-Item C:\LocalBuilds, $env:USERPROFILE\.nuget, $env:LOCALAPPDATA\UnrealEngine, $env:LOCALAPPDATA\UnrealBuildTool -Recurse -Force -ErrorAction SilentlyContinue

# The agent image.
FROM base

COPY --from=ue-builder /UnrealEngine C:/UnrealEngine
ENV UE_ROOT="C:\UnrealEngine"

# Engine prerequisites (VC++ and DirectX redistributables), needed by UnrealEditor-Cmd when cooking.
# Setup.bat installed them in ue-builder, but this stage starts from base, so they are installed again
# here from the installed build's copy of the installer.
RUN $p = Start-Process -FilePath C:\UnrealEngine\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -Wait -PassThru; \
    if ($p.ExitCode -notin 0,3010) { throw ('UEPrereqSetup_x64.exe failed with exit code ' + $p.ExitCode) }

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
COPY esp-idf/eim-config.toml C:/TEMP/eim-config.toml
RUN eim install --config C:\TEMP\eim-config.toml --non-interactive true
RUN eim select v5.1.7

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="true"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="true"
ENV DOTNET_NOLOGO="true"

# Outside C:\Users\jenkins (AGENT_WORKDIR), so a volume mounted there cannot hide it.
COPY windows/jenkins-agent-entrypoint.ps1 C:/ProgramData/Jenkins/jenkins-agent-entrypoint.ps1
ENTRYPOINT ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\ProgramData\\Jenkins\\jenkins-agent-entrypoint.ps1"]
