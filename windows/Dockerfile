# Unreal Engine version baked into the agent. Bump together with UE_ARCHIVE_URL / UE_ARCHIVE_SHA256.
ARG UE_VERSION=5.8.3

# ---------------------------------------------------------------------------------------------
# Stage: unreal-engine
# Epic only ships the Windows engine through the Epic Games Launcher, which cannot run in a
# container, so the engine comes from a zip of a Launcher install made with
# tools/New-UnrealEngineArchive.ps1 (see docs/unreal-engine.md) hosted at UE_ARCHIVE_URL.
# Doing this in its own stage keeps the build arg (which may carry credentials) out of the final
# image and means the archive is never stored in a layer of the agent image.
# ---------------------------------------------------------------------------------------------
FROM mcr.microsoft.com/windows/server:ltsc2025 AS unreal-engine
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG UE_VERSION
ARG UE_ARCHIVE_URL
# Optional but recommended: sha256 of the archive (printed by New-UnrealEngineArchive.ps1).
ARG UE_ARCHIVE_SHA256=""

# Download, verify, extract (tar.exe handles zip64 archives, Expand-Archive does not) and delete
# the archive in one step. Requires a daemon storage-opts size large enough for zip + engine.
RUN if (-not $env:UE_ARCHIVE_URL) { throw 'UE_ARCHIVE_URL build arg is required: URL of the Win64 engine zip, see docs/unreal-engine.md' }; \
    curl.exe -fSL --retry 5 --retry-delay 10 -o C:\ue.zip $env:UE_ARCHIVE_URL; \
    if ($LASTEXITCODE -ne 0) { throw ('Engine download failed, curl exit code ' + $LASTEXITCODE) }; \
    if ($env:UE_ARCHIVE_SHA256) { \
        $hash = (Get-FileHash C:\ue.zip -Algorithm SHA256).Hash; \
        if ($hash -ne $env:UE_ARCHIVE_SHA256) { throw ('Engine archive SHA256 mismatch, got ' + $hash) } \
    }; \
    New-Item -ItemType Directory -Path C:\ue-extract | Out-Null; \
    tar.exe -xf C:\ue.zip -C C:\ue-extract; \
    if ($LASTEXITCODE -ne 0) { throw ('Engine extraction failed, tar exit code ' + $LASTEXITCODE) }; \
    Remove-Item C:\ue.zip -Force; \
    $versionFile = Get-ChildItem -Path C:\ue-extract -Filter Build.version -Recurse -Depth 3 | Where-Object { $_.Directory.Name -eq 'Build' -and $_.Directory.Parent.Name -eq 'Engine' } | Select-Object -First 1; \
    if (-not $versionFile) { throw 'Engine archive does not contain Engine\Build\Build.version' }; \
    Move-Item -Path $versionFile.Directory.Parent.Parent.FullName -Destination C:\UnrealEngine; \
    if (Test-Path C:\ue-extract) { Remove-Item C:\ue-extract -Recurse -Force }; \
    $v = Get-Content C:\UnrealEngine\Engine\Build\Build.version -Raw | ConvertFrom-Json; \
    $found = '{0}.{1}.{2}' -f $v.MajorVersion, $v.MinorVersion, $v.PatchVersion; \
    if ($found -ne $env:UE_VERSION) { throw ('Engine archive contains UE ' + $found + ', expected ' + $env:UE_VERSION) }

# ---------------------------------------------------------------------------------------------
# Stage: final agent image
# ---------------------------------------------------------------------------------------------
FROM mcr.microsoft.com/windows/server:ltsc2025

# Unreal Engine (Windows host): Win64 x64/arm64/arm64ec game targets, OpenXR and Microsoft Store
# (.msixvc via the GDK plug-ins). Android/Linux are deliberately left to the Linux agent.
# Copied first so this ~40GB layer is only rebuilt when the base image or the engine changes.
# No ACL changes: jenkins is a local Administrator, and an icacls pass over the engine would
# duplicate every file into a new layer.
COPY --from=unreal-engine C:/UnrealEngine C:/UnrealEngine
ENV UE_ROOT="C:\UnrealEngine"

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Runtime prerequisites the Launcher normally installs (VC++ and DirectX redistributables), needed
# by UnrealEditor-Cmd when cooking.
RUN $p = Start-Process -FilePath C:\UnrealEngine\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -Wait -PassThru; \
    if ($p.ExitCode -notin 0,3010) { throw ('UEPrereqSetup_x64.exe failed with exit code ' + $p.ExitCode) }

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
# Verify build tools installation
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]
RUN if (-not (Test-Path 'C:\BuildTools')) { throw 'Build Tools installation failed' }

# Public Microsoft GDK (PC edition). UE 5.8 ships the Microsoft GDK Store/Runtime plug-ins for Win64,
# which package games as .msixvc for the Microsoft Store / Xbox PC app (UE5's replacement for UWP);
# packaging needs the GDK tools (makepkg) on the build machine. This is NOT the NDA console GDKX.
# Pinned to the winget manifest of Microsoft.Gaming.GDK 2604.5.7903.
ARG GDK_URL=https://github.com/microsoft/GDK/releases/download/April-2026-Update-5-v2604.5.7903/GDK_2604.5.7903.zip
ARG GDK_SHA256=304A4C154C0896DC6C3F66ED237E2360F67E4161F9078A7D10E8C2D8ECED1A8A
RUN curl.exe -fSL --retry 5 -o C:\TEMP\gdk.zip $env:GDK_URL; \
    if ($LASTEXITCODE -ne 0) { throw ('GDK download failed, curl exit code ' + $LASTEXITCODE) }; \
    if ((Get-FileHash C:\TEMP\gdk.zip -Algorithm SHA256).Hash -ne $env:GDK_SHA256) { throw 'GDK archive SHA256 mismatch' }; \
    New-Item -ItemType Directory -Path C:\TEMP\gdk | Out-Null; \
    tar.exe -xf C:\TEMP\gdk.zip -C C:\TEMP\gdk; \
    if ($LASTEXITCODE -ne 0) { throw ('GDK extraction failed, tar exit code ' + $LASTEXITCODE) }; \
    $p = Start-Process -FilePath C:\TEMP\gdk\PGDK.exe -ArgumentList '/quiet','/norestart','/log','C:\TEMP\gdk-install.log' -Wait -PassThru; \
    if ($p.ExitCode -notin 0,3010) { Get-Content C:\TEMP\gdk-install*.log -Tail 200 -ErrorAction SilentlyContinue; throw ('GDK install failed with exit code ' + $p.ExitCode) }; \
    Remove-Item C:\TEMP\gdk, C:\TEMP\gdk.zip, C:\TEMP\gdk-install*.log -Recurse -Force

# Install esp-idf
ADD https://github.com/espressif/idf-im-ui/releases/download/v0.12.2/eim-cli-windows-x64.exe eim-cli/bin/eim.exe
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\ProgramData\chocolatey\bin;' + 'C:\eim-cli\bin;' + 'C:\cargo\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)

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
