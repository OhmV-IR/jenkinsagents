FROM mcr.microsoft.com/windows/server:ltsc2025

# Set Shell to PowerShell for all subsequent RUN commands
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# 1. Install Chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install basic build dependencies
RUN choco install -y git cmake ninja curl openjdk17 make python312

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

ENV PATH="C:\\BuildTools\\VC\\Tools\\MSVC\\14.50.35717\\bin\\HostX64\\x64;C:\\BuildTools\\MSBuild\\Current\\bin\\Roslyn;C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.26100.0\\x64;C:\\Program Files (x86)\\Windows Kits\\10\\bin\\x64;C:\\BuildTools\\MSBuild\\Current\\Bin\\amd64;C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319;C:\\BuildTools\\Common7\\IDE\\;C:\\BuildTools\\Common7\\Tools\\;C:\\Python312\\Scripts\\;C:\\Python312\\;C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.17.10-hotspot\\bin;C:\\Windows\\system32;C:\\Windows;C:\\Windows\\System32\\Wbem;C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\;C:\\Windows\\System32\\OpenSSH\\;C:\\ProgramData\\chocolatey\\bin;C:\\Program Files\\Git\\cmd;C:\\Program Files\\CMake\\bin;C:\\Program Files\\dotnet\\;C:\\Users\\jenkins.6EB46AF8FA13\\AppData\\Local\\Microsoft\\WindowsApps;C:\\BuildTools\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\CMake\\bin;C:\\BuildTools\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\Ninja"
# 4. Setup Jenkins User
RUN net user jenkins /add /passwordreq:no; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins -Force; \
    icacls C:\\Users\\jenkins /grant 'jenkins:(OI)(CI)F' /T

# 5. Environment Configuration
ENV JENKINS_URL="" \ 
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins"

USER jenkins
WORKDIR C:\\Users\\jenkins

ENTRYPOINT ["powershell", "-NoLogo", "-Command", \
    "$ErrorActionPreference = 'Stop'; \
    Write-Host 'Fetching agent.jar from' $env:JENKINS_URL; \
    Invoke-WebRequest -UseBasicParsing -Uri \"$($env:JENKINS_URL)/jnlpJars/agent.jar\" -OutFile 'agent.jar'; \
    Write-Host 'Starting Jenkins Agent...'; \
    java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
