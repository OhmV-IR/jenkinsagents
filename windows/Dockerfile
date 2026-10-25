# Built from this folder:
#   docker build --build-arg GITHUB_TOKEN --target ue-builder -t jenkins-agent-windows-ue-builder:latest -f windows/Dockerfile windows
#   docker build --build-arg GITHUB_TOKEN -t jenkins-agent-windows:latest -f windows/Dockerfile windows
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

FROM base AS ue-builder
ARG UE_GIT_TAGS=5.8.4-release
ARG GITHUB_TOKEN
# Extra BuildGraph arguments (passed to every engine build), e.g. -set:WithFullDebugInfo=true
ARG UE_BUILDGRAPH_EXTRA_ARGS=""
ENV UE_ROOT="C:\UnrealEngine"
# Installed build of each engine: Win64 target platform (plus ARM64 if that engine version has an
# installed-build option for it), Development and Shipping game configurations only, with Server and
# Client targets, no DDC.
# Clone, Setup.bat and the build run in one step, and everything but the output (source tree with its
# Setup.bat dependencies, intermediates, local caches) is deleted after each engine in that same step,
# so neither the source nor the build scratch ever becomes part of a layer, and only one engine's
# scratch exists at a time. The token is sent as a one-off header, so
# it is not written to .git/config. Platforms this host never builds are skipped (Android/Linux live
# on the Linux agent). *.pdb files are dropped as the Launcher build does (they are only needed to debug
# the engine itself).
# IOS and TVOS dependencies are NOT excluded, even though this host never builds for them:
# GitDependencies' --exclude=<X> drops every file under any folder named <X>, and AutomationTool always
# compiles IOS.Automation (plus TVOS.Automation and VisionOS.Automation, which reference it), whose
# embedded resources (e.g. Engine\Source\Programs\AutomationTool\IOS\Resources\GreenCheck.png) are part
# of that dependency set. With --exclude=IOS the BuildGraph run dies with MSB3554 before any engine code
# is built. The extra download is deleted with the rest of the source tree, so the layer does not grow,
# and WithIOS/WithTVOS stay false, so nothing iOS ends up in the installed build.
# Setup.bat is not safe to run unattended in a container as shipped: its last command is
# `UnrealVersionSelector-Win64-Shipping.exe /register`, which opens a modal "Register Unreal Engine file
# types?" dialog when the .uproject associations are not registered (always the case here). A container
# has no desktop to answer it on, so the step blocks forever at 0% CPU, right after the "Installing
# prerequisites..." line. Both that call and the prerequisites installer are commented out of Setup.bat;
# the prerequisites (UEPrereqSetup_x64.exe) are then installed directly, with a timeout and a logged exit
# code, and --force stops GitDependencies from asking before it overwrites files.
# BuildGraph is retried up to 10 times: UBT can race and compile a .cpp before its .ispc.generated.h
# exists (e.g. DeadBlending.cpp in 5.5), and since the build is incremental a retry gets past it.
# The error lines of the UBT logs are printed before each retry, as the logs are deleted with the
# source tree and the console output does not always show which action failed.
# Before that, UBA's forced retry reruns any single action that fails under UBA once more without UBA
# (logged as "This action will retry without UBA"), which should get past the race without a full
# BuildGraph retry. It is set by copying BuildConfiguration.xml into Engine\Saved\UnrealBuildTool of
# the source tree, so it only applies to the engine build and is deleted with the source.
# The engine's bundled dotnet leaves processes behind after RunUAT exits (MSBuild nodes, the MSBuild
# server, the Roslyn compiler server), which keep dotnet.exe and its DLLs locked so rmdir of the source
# tree fails with "Access is denied". Node reuse and the build servers are turned off, and any process
# still running out of C:\UE is killed before the source tree is deleted, which is retried until it is gone.
COPY BuildConfiguration.xml C:/TEMP/BuildConfiguration.xml
ENV MSBUILDDISABLENODEREUSE=1 DOTNET_CLI_USE_MSBUILD_SERVER=0 UseSharedCompilation=false
RUN if (-not $env:GITHUB_TOKEN) { throw 'GITHUB_TOKEN build arg is required (GitHub account with access to EpicGames/UnrealEngine)' }; \
    $tags = @($env:UE_GIT_TAGS -split ' ' | Where-Object { $_ }); \
    if (-not $tags) { throw 'UE_GIT_TAGS is empty' }; \
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $env:GITHUB_TOKEN)); \
    New-Item -ItemType Directory -Path $env:UE_ROOT -Force | Out-Null; \
    foreach ($tag in $tags) { \
        $dest = Join-Path $env:UE_ROOT $tag; \
        Write-Host ('=== Building Unreal Engine ' + $tag + ' into ' + $dest + ' ==='); \
        if (Test-Path $dest) { throw ($dest + ' already exists (' + $tag + ' listed twice in UE_GIT_TAGS?)') }; \
        & 'C:\Program Files\Git\cmd\git.exe' -c core.longpaths=true -c ('http.extraHeader=Authorization: Basic ' + $auth) \
            clone --depth 1 --branch $tag https://github.com/EpicGames/UnrealEngine.git C:\UE; \
        if ($LASTEXITCODE -ne 0) { throw ('git clone of ' + $tag + ' failed with exit code ' + $LASTEXITCODE) }; \
        Set-Location C:\UE; \
        (Get-Content Setup.bat) -replace '^(.*(PrereqSetup|UnrealVersionSelector).*)$', 'rem $1' | Set-Content Setup.bat -Encoding ascii; \
        & cmd /c Setup.bat --force --exclude=Android --exclude=Linux --exclude=LinuxArm64 --exclude=Mac; \
        if ($LASTEXITCODE -ne 0) { throw ('Setup.bat failed with exit code ' + $LASTEXITCODE) }; \
        if (-not (Test-Path C:\UE\Engine\Source\Programs\AutomationTool\IOS\Resources\GreenCheck.png)) { throw 'AutomationTool IOS resources missing after Setup.bat; IOS dependencies must not be excluded' }; \
        Write-Host 'Installing engine prerequisites (UEPrereqSetup_x64.exe)...'; \
        $prereq = Start-Process -FilePath C:\UE\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -PassThru; \
        $null = $prereq.Handle; \
        if (-not $prereq.WaitForExit(1800000)) { $prereq.Kill(); throw 'UEPrereqSetup_x64.exe was still running after 30 minutes' }; \
        if ($prereq.ExitCode -notin 0, 3010) { Write-Warning ('UEPrereqSetup_x64.exe exited with ' + $prereq.ExitCode + ' (Setup.bat never checked this exit code either)') }; \
        $xml = Get-Content Engine\Build\InstalledEngineBuild.xml -Raw; \
        foreach ($opt in 'BuiltDirectory','WithDDC','WithServer','WithClient','GameConfigurations','WithWin64','WithLinux','WithLinuxArm64','WithAndroid','WithMac','WithIOS','WithTVOS') { \
            if ($xml -notmatch ('<Option\s+Name=.' + $opt + '.')) { throw ('InstalledEngineBuild.xml in ' + $tag + ' has no ' + $opt + ' option; update the BuildGraph -set: list') } \
        }; \
        $armOptions = @([regex]::Matches($xml, '<Option\s+Name=.(With\w*Win\w*Arm64\w*).') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique); \
        if ($armOptions) { Write-Host ('Enabling Windows ARM64 options: ' + ($armOptions -join ', ')) } \
        else { Write-Warning ('No Windows ARM64 installed-build option found for ' + $tag + ', so the build only contains x64 Win64 binaries. If it is named differently, pass it via UE_BUILDGRAPH_EXTRA_ARGS.') }; \
        $setArgs = @('-set:BuiltDirectory=C:\LocalBuilds', '-set:WithDDC=false', '-set:WithServer=true', '-set:WithClient=true', \
            '-set:GameConfigurations=Development;Shipping', \
            '-set:WithWin64=true', '-set:WithLinux=false', '-set:WithLinuxArm64=false', '-set:WithAndroid=false', \
            '-set:WithMac=false', '-set:WithIOS=false', '-set:WithTVOS=false') + \
            @($armOptions | ForEach-Object { '-set:' + $_ + '=true' }) + \
            @($env:UE_BUILDGRAPH_EXTRA_ARGS -split ' ' | Where-Object { $_ }); \
        New-Item -ItemType Directory -Path Engine\Saved\UnrealBuildTool -Force | Out-Null; \
        Copy-Item C:\TEMP\BuildConfiguration.xml Engine\Saved\UnrealBuildTool\BuildConfiguration.xml; \
        for ($attempt = 1; ; $attempt++) { \
            & .\Engine\Build\BatchFiles\RunUAT.bat BuildGraph '-script=Engine/Build/InstalledEngineBuild.xml' '-target=Make Installed Build Win64' @setArgs; \
            $rc = $LASTEXITCODE; \
            if ($rc -eq 0) { break }; \
            Get-ChildItem C:\UE\Engine\Programs\AutomationTool\Saved\Logs -Filter *.txt -ErrorAction SilentlyContinue | \
                Select-String -Pattern ': (fatal )?error' | Select-Object -First 50 | ForEach-Object { Write-Host ($_.Filename + ': ' + $_.Line) }; \
            if ($attempt -ge 10) { throw ('BuildGraph of ' + $tag + ' failed after ' + $attempt + ' attempts (last exit code ' + $rc + ')') }; \
            Write-Host ('=== BuildGraph of ' + $tag + ' failed with exit code ' + $rc + ', retrying (attempt ' + ($attempt + 1) + '/10) ==='); \
        }; \
        if (-not (Test-Path C:\LocalBuilds\Windows\Engine\Build\Build.version)) { throw 'Installed build not found in C:\LocalBuilds\Windows' }; \
        Get-ChildItem C:\LocalBuilds\Windows -Recurse -Filter *.pdb -File | Remove-Item -Force -ErrorAction Continue; \
        Move-Item C:\LocalBuilds\Windows $dest; \
        Set-Location C:\; \
        for ($attempt = 1; Test-Path C:\UE; $attempt++) { \
            Get-Process | Where-Object { $_.Path -like 'C:\UE\*' } | ForEach-Object { Write-Host ('Stopping ' + $_.Path + ' (PID ' + $_.Id + ')'); $_.Kill(); $_.WaitForExit(30000) | Out-Null }; \
            cmd /c rmdir /s /q \\?\C:\UE; \
            if (-not (Test-Path C:\UE)) { break }; \
            if ($attempt -ge 5) { throw ('Could not delete C:\UE after building ' + $tag) }; \
            Start-Sleep -Seconds 10; \
        }; \
        Remove-Item C:\LocalBuilds, $env:USERPROFILE\.nuget, $env:LOCALAPPDATA\UnrealEngine, $env:LOCALAPPDATA\UnrealBuildTool -Recurse -Force -ErrorAction SilentlyContinue; \
    }

FROM base

COPY --from=ue-builder /UnrealEngine C:/UnrealEngine
ENV UE_ROOT="C:\UnrealEngine"
# Each engine version ships its own prerequisites installer, so run every one of them.
RUN foreach ($engine in Get-ChildItem $env:UE_ROOT -Directory) { \
        Write-Host ('Installing prerequisites of Unreal Engine ' + $engine.Name); \
        $p = Start-Process -FilePath (Join-Path $engine.FullName 'Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe') -ArgumentList '/quiet','/norestart' -Wait -PassThru; \
        if ($p.ExitCode -notin 0,3010) { throw ('UEPrereqSetup_x64.exe of ' + $engine.Name + ' failed with exit code ' + $p.ExitCode) } \
    }

# Everything below is not needed by the engine build, so changing it does not rebuild the engines.
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
