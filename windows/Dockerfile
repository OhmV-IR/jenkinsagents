FROM mcr.microsoft.com/windows/server:ltsc2025

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

ARG UE_GIT_TAG=5.8.3-release
ARG GITHUB_TOKEN
# The token is sent as a one-off header, so it is not written to .git/config.
RUN if (-not $env:GITHUB_TOKEN) { throw 'GITHUB_TOKEN build arg is required (GitHub account with access to EpicGames/UnrealEngine)' }; \
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $env:GITHUB_TOKEN)); \
    & 'C:\Program Files\Git\cmd\git.exe' -c core.longpaths=true -c ('http.extraHeader=Authorization: Basic ' + $auth) \
        clone --depth 1 --branch $env:UE_GIT_TAG https://github.com/EpicGames/UnrealEngine.git C:\UE; \
    if ($LASTEXITCODE -ne 0) { throw ('git clone failed with exit code ' + $LASTEXITCODE) }

# Binary dependencies and UE prerequisites (Setup.bat runs UEPrereqSetup_x64.exe, which the DDC
# step needs). Platforms this host never builds are skipped: Android/Linux live on the Linux agent.
RUN Set-Location C:\UE; \
    & cmd /c Setup.bat --exclude=Android --exclude=Linux --exclude=LinuxArm64 --exclude=Mac --exclude=IOS --exclude=TVOS; \
    if ($LASTEXITCODE -ne 0) { throw ('Setup.bat failed with exit code ' + $LASTEXITCODE) }

ENV UE_ROOT="C:\UnrealEngine"

# Extra BuildGraph arguments, e.g. -set:GameConfigurations=Development;Shipping
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
# Installed build: Win64 target platform (plus ARM64 if this engine version has an installed-build
# option for it), Server targets, editor/template DDC. The source tree, intermediates and local
# caches are deleted in the same step so the build scratch never becomes part of a layer; *.pdb
# files are dropped as the Launcher build does (they are only needed to debug the engine itself).
RUN Set-Location C:\UE; \
    $xml = Get-Content Engine\Build\InstalledEngineBuild.xml -Raw; \
    foreach ($opt in 'BuiltDirectory','WithDDC','WithServer','WithClient','WithWin64','WithLinux','WithLinuxArm64','WithAndroid','WithMac','WithIOS','WithTVOS') { \
        if ($xml -notmatch ('<Option\s+Name=.' + $opt + '.')) { throw ('InstalledEngineBuild.xml in ' + $env:UE_GIT_TAG + ' has no ' + $opt + ' option; update the BuildGraph -set: list') } \
    }; \
    $armOptions = @([regex]::Matches($xml, '<Option\s+Name=.(With\w*Win\w*Arm64\w*).') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique); \
    if ($armOptions) { Write-Host ('Enabling Windows ARM64 options: ' + ($armOptions -join ', ')) } \
    else { Write-Warning ('No Windows ARM64 installed-build option found for ' + $env:UE_GIT_TAG + ', so the build only contains x64 Win64 binaries. If it is named differently, pass it via UE_BUILDGRAPH_EXTRA_ARGS.') }; \
    $setArgs = @('-set:BuiltDirectory=C:\LocalBuilds', '-set:WithDDC=true', '-set:WithServer=true', '-set:WithClient=false', \
        '-set:WithWin64=true', '-set:WithLinux=false', '-set:WithLinuxArm64=false', '-set:WithAndroid=false', \
        '-set:WithMac=false', '-set:WithIOS=false', '-set:WithTVOS=false') + \
        @($armOptions | ForEach-Object { '-set:' + $_ + '=true' }) + \
        @($env:UE_BUILDGRAPH_EXTRA_ARGS -split ' ' | Where-Object { $_ }); \
    & .\Engine\Build\BatchFiles\RunUAT.bat BuildGraph '-script=Engine/Build/InstalledEngineBuild.xml' '-target=Make Installed Build Win64' @setArgs; \
    if ($LASTEXITCODE -ne 0) { throw ('BuildGraph failed with exit code ' + $LASTEXITCODE) }; \
    if (-not (Test-Path C:\LocalBuilds\Windows\Engine\Build\Build.version)) { throw 'Installed build not found in C:\LocalBuilds\Windows' }; \
    Get-ChildItem C:\LocalBuilds\Windows -Recurse -Filter *.pdb -File | Remove-Item -Force -ErrorAction Continue; \
    Set-Location C:\; \
    cmd /c rmdir /s /q \\?\C:\UE; \
    Remove-Item $env:USERPROFILE\.nuget, $env:LOCALAPPDATA\UnrealEngine, $env:LOCALAPPDATA\UnrealBuildTool -Recurse -Force -ErrorAction SilentlyContinue


# Runtime prerequisites Setup.bat/the Launcher normally install (VC++ and DirectX redistributables), needed
# by UnrealEditor-Cmd when cooking.
RUN $p = Start-Process -FilePath C:\UnrealEngine\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -Wait -PassThru; \
    if ($p.ExitCode -notin 0,3010) { throw ('UEPrereqSetup_x64.exe failed with exit code ' + $p.ExitCode) }

# Rust toolchain directories (the jenkins user comes from the ESP-IDF base image)
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
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\ProgramData\chocolatey\bin;' + 'C:\eim-cli\bin;' + 'C:\cargo\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)

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

# Install rust
ENV CARGO_HOME="C:\cargo" \
    RUSTUP_HOME="C:\rustup"

RUN Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "C:\TEMP\rustup-init.exe"; \
    C:\TEMP\rustup-init.exe -y --default-toolchain stable --profile minimal --quiet;
RUN rustup component add rustfmt clippy
RUN rustup target add aarch64-linux-android x86_64-pc-windows-gnu x86_64-linux-android aarch64-apple-ios armv7-linux-androideabi i686-linux-android
RUN cargo install protoc-gen-prost
RUN Remove-Item -Path C:\TEMP\rustup-init.exe -Force

COPY eim-config.toml eim-config.toml
RUN eim install --config eim-config.toml --non-interactive true
RUN eim select v5.1.7

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
