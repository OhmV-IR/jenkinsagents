FROM mcr.microsoft.com/windows/servercore:ltsc2022

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
RUN Write-Host 'Downloading VS 2026 Build Tools...'; \
    Invoke-WebRequest -Uri https://aka.ms/vs/18/Stable/vs_buildtools.exe -OutFile C:\TEMP\vs_buildtools.exe; \
    Write-Host 'Installing MSVC Components...'; \
    Start-Process 'C:\TEMP\vs_buildtools.exe' -ArgumentList @( \
    '--quiet', \
    '--wait', \
    '--norestart', \
    '--nocache', \
    '--config', 'C:\TEMP\.vsconfig' \
) -Wait; \
    Write-Host 'Cleaning up installer...'; \
    Remove-Item -Path C:\TEMP -Recurse -Force

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

# Add MSVC to Path
RUN $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine'); \
    setx /M PATH $env:Path

USER jenkins
WORKDIR C:\\Users\\jenkins

ENTRYPOINT ["powershell", "-NoLogo", "-Command", \
    "$ErrorActionPreference = 'Stop'; \
    Write-Host 'Fetching agent.jar from' $env:JENKINS_URL; \
    Invoke-WebRequest -UseBasicParsing -Uri \"$($env:JENKINS_URL)/jnlpJars/agent.jar\" -OutFile 'agent.jar'; \
    Write-Host 'Starting Jenkins Agent...'; \
    java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
