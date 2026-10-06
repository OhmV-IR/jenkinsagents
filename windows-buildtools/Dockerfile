# Windows build tools base image: Chocolatey + basic build tools, VS 2026 Build Tools. Base of esp-idf-windows (and so of jenkins-agent-windows) and of the Unreal Engine
# builder, so the multi-GB Visual Studio install is never re-run by edits to those Dockerfiles.
# Only rebuilt on purpose: BUILD_WINDOWS_BUILDTOOLS in the Jenkinsfile, or a change under
# windows-buildtools/.
#
# .vsconfig covers the agent (MSVC x64/ARM64/ARM64EC incl. the 14.50 toolset UE 5.8 prefers,
# Windows SDK 26100, CMake, ASAN, ATL/MFC) and the Unreal Engine source build (.NET Framework
# 4.6.2 targeting pack and 4.8 SDK for the engine's C# tools).
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
# Verify build tools installation
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]
RUN if (-not (Test-Path 'C:\BuildTools')) { throw 'Build Tools installation failed' }
