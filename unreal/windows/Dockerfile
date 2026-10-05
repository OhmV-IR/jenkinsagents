# Unreal Engine installed build for the Windows agent, compiled from Epic's GitHub source.
#
# Produces a small image (nanoserver + C:\UnrealEngine) that jenkins-agent-windows copies the
# engine out of. The engine build takes many hours, so this image is only rebuilt on purpose
# (BUILD_UNREAL_ENGINE in the Jenkinsfile).
#
#   docker build -m 32g --build-arg GITHUB_TOKEN=... --build-arg UE_GIT_TAG=5.8.3-release ^
#       --build-arg BUILDTOOLS_IMAGE=registry.ohmvir.dev/windows-buildtools:latest ^
#       -t localhost:5000/unreal-engine-windows:5.8.3-release unreal/windows
#
# GITHUB_TOKEN must belong to a GitHub account linked to an Epic account (access to EpicGames/UnrealEngine).
# The Docker daemon needs "storage-opts": ["size=400GB"] (see docs/unreal-engine.md).

# Git tag of EpicGames/UnrealEngine to build.
ARG UE_GIT_TAG=5.8.3-release
# Windows build tools image (windows-buildtools/Dockerfile): VS 2026 Build Tools incl. MSVC 14.50
# x64/ARM64, Windows SDK 26100, .NET Framework targeting pack, and the public Microsoft GDK.
# Pulled through registry.ohmvir.dev (pushes go to localhost:5000, see the Jenkinsfile).
ARG BUILDTOOLS_IMAGE=registry.ohmvir.dev/windows-buildtools:latest

# ---------------------------------------------------------------------------------------------
# Stage: source. Shallow clone of the tag. Kept separate because the classic Windows builder has
# no build secrets: build args are recorded in the history of every later step of the stage that
# declares them, so GITHUB_TOKEN is confined to this throwaway stage (which only ever exists on
# the build host) and the builder stage below copies the files instead of inheriting its history.
# ---------------------------------------------------------------------------------------------
FROM mcr.microsoft.com/windows/server:ltsc2025 AS source
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Git for Windows 2.55.0, pinned to its winget manifest.
ARG GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.1/Git-2.55.0-64-bit.exe
ARG GIT_SHA256=0C66E4A5875DA5A74F9754386DE7555BA301503B03BBDCDBAFA69DC6464E548D
RUN reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f; \
    curl.exe -fSL --retry 5 -o C:\git-setup.exe $env:GIT_URL; \
    if ($LASTEXITCODE -ne 0) { throw ('Git download failed, curl exit code ' + $LASTEXITCODE) }; \
    if ((Get-FileHash C:\git-setup.exe -Algorithm SHA256).Hash -ne $env:GIT_SHA256) { throw 'Git installer SHA256 mismatch' }; \
    $p = Start-Process -FilePath C:\git-setup.exe -ArgumentList '/SP-','/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/ALLUSERS','/NOICONS' -Wait -PassThru; \
    if ($p.ExitCode -ne 0) { throw ('Git install failed with exit code ' + $p.ExitCode) }; \
    Remove-Item C:\git-setup.exe -Force

ARG UE_GIT_TAG
ARG GITHUB_TOKEN
# The token is sent as a one-off header, so it is not written to .git/config.
RUN if (-not $env:GITHUB_TOKEN) { throw 'GITHUB_TOKEN build arg is required (GitHub account with access to EpicGames/UnrealEngine)' }; \
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $env:GITHUB_TOKEN)); \
    & 'C:\Program Files\Git\cmd\git.exe' -c core.longpaths=true -c ('http.extraHeader=Authorization: Basic ' + $auth) \
        clone --depth 1 --branch $env:UE_GIT_TAG https://github.com/EpicGames/UnrealEngine.git C:\UE; \
    if ($LASTEXITCODE -ne 0) { throw ('git clone failed with exit code ' + $LASTEXITCODE) }

# ---------------------------------------------------------------------------------------------
# Stage: builder. Toolchains come from the windows-buildtools base image (MSVC 14.50, since 14.51
# removed <hash_map> and breaks UE 5.8; the GDK so the MSGameStore / MSGamingRuntime plug-ins
# compile against it), then source, deps and build.
# ---------------------------------------------------------------------------------------------
FROM ${BUILDTOOLS_IMAGE} AS builder
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

COPY --from=source C:/UE C:/UE

# Binary dependencies and UE prerequisites (Setup.bat runs UEPrereqSetup_x64.exe, which the DDC
# step needs). Platforms this host never builds are skipped: Android/Linux live on the Linux agent.
RUN Set-Location C:\UE; \
    & cmd /c Setup.bat --exclude=Android --exclude=Linux --exclude=LinuxArm64 --exclude=Mac --exclude=IOS --exclude=TVOS; \
    if ($LASTEXITCODE -ne 0) { throw ('Setup.bat failed with exit code ' + $LASTEXITCODE) }

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

# ---------------------------------------------------------------------------------------------
# Result image: only the installed build, on the smallest Windows base.
# ---------------------------------------------------------------------------------------------
FROM mcr.microsoft.com/windows/nanoserver:ltsc2025
ARG UE_GIT_TAG
LABEL org.opencontainers.image.title="unreal-engine-windows" \
      org.opencontainers.image.version="${UE_GIT_TAG}"
COPY --from=builder C:/LocalBuilds/Windows C:/UnrealEngine
