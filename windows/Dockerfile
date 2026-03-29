FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command"]

# Install chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# some basic packages
RUN choco install -y git cmake ninja curl openjdk openjdk17 microsoft-openjdk-21 make python312

# Add MSVC
ADD https://aka.ms/vs/17/release/vs_BuildTools.exe C:\TEMP\buildtools.exe
RUN powershell -NoLogo -Command \
    "Start-Process 'C:\TEMP\buildtools.exe' -ArgumentList '--quiet','--wait','--norestart','--nocache', \
    '--installPath','C:\MSVC', \
    '--add','Microsoft.VisualStudio.Workload.VCTools', \
    '--add','Microsoft.VisualStudio.Component.VC.Tools.x86.x64', \
    '--add','Microsoft.VisualStudio.Component.Windows11SDK.26100' \
    -Wait"


RUN net user jenkins /add
RUN net localgroup Administrators jenkins /add
RUN New-Item -ItemType Directory -Path C:\Users\jenkins | Out-Null

ENV JENKINS_URL=""
ENV AGENT_NAME=""
ENV AGENT_SECRET=""
ENV AGENT_WORKDIR="C:\Users\jenkins"

USER jenkins
WORKDIR C:\Users\jenkins

ENTRYPOINT ["powershell", "-NoLogo", "-Command", "curl -sO $env:JENKINS_URL/jnlpJars/agent.jar; java -jar agent.jar -url $env:JENKINS_URL -secret $env:AGENT_SECRET -name $env:AGENT_NAME -webSocket -workDir $env:AGENT_WORKDIR"]
