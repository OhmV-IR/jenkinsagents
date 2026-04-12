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
# Using RUN instead of ADD to keep the image slim and avoid 'Directory Name Invalid' errors
RUN mkdir C:\TEMP; \
    Write-Host 'Downloading VS 2026 Build Tools...'; \
    Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_BuildTools.exe -OutFile C:\TEMP\vs_buildtools.exe; \
    Write-Host 'Installing MSVC Components...'; \
    Start-Process -FilePath 'C:\TEMP\vs_buildtools.exe' -ArgumentList \
        '--quiet', '--wait', '--norestart', '--nocache', \
        '--installPath C:\MSVC', \
        '--add Microsoft.VisualStudio.Workload.VCTools', \
        '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64', \
        '--add Microsoft.VisualStudio.Component.Windows11SDK.26100' \
        -Wait; \
    Write-Host 'Cleaning up installer...'; \
    Remove-Item -Path C:\TEMP -Recurse -Force

# 4. Setup Jenkins User
RUN net user jenkins /add; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins -Force

# 5. Environment Configuration
ENV JENKINS_URL="" \
    AGENT_NAME="" \
    AGENT_SECRET="" \
    AGENT_WORKDIR="C:\Users\jenkins"

# Add MSVC to Path so CMake finds it automatically
# Note: Check the exact version folder after your first build and update this path if needed
ENV PATH="C:\MSVC\VC\Tools\MSVC\14.40.33810\bin\Hostx64\x64;${PATH}"

USER jenkins
WORKDIR C:\Users\jenkins

# 6. Entrypoint with improved connection logic
ENTRYPOINT ["powershell", "-NoLogo", "-Command", \
    "Invoke-WebRequest -Uri \"$env:JENKINS_URL/jnlpJars/agent.jar\" -OutFile agent.jar; \
    java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
