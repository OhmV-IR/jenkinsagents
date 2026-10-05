# ESP-IDF toolchains, installed with Espressif's eim as the jenkins user, on top of the Windows
# build tools image. This image is the base of jenkins-agent-windows, so editing the agent never
# re-runs the (slow) ESP-IDF install. Only rebuilt on purpose: BUILD_ESP_IDF in the Jenkinsfile,
# or a change under esp-idf/windows/ (and whenever windows-buildtools is rebuilt, so the chain
# never goes stale).
#
# A base image rather than a COPY source: eim writes per-user state and absolute paths that only
# stay valid if the agent is built on top of this image.
ARG BUILDTOOLS_IMAGE=localhost:5000/windows-buildtools:latest
FROM ${BUILDTOOLS_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Install esp-idf (eim CLI, pinned and verified). The machine PATH also gets the agent's cargo bin
# directory, as before, so all PATH entries are set in one place.
ARG EIM_VERSION=0.12.2
ARG EIM_EXE_SHA256=6FE22437B7BAE5A4EF4A8A0490E067CB02896A20EAFBED8AD56A9E8345347F80
RUN New-Item -ItemType Directory -Path C:\eim-cli\bin -Force | Out-Null; \
    curl.exe -fSL --retry 5 -o C:\eim-cli\bin\eim.exe ('https://github.com/espressif/idf-im-ui/releases/download/v' + $env:EIM_VERSION + '/eim-cli-windows-x64.exe'); \
    if ($LASTEXITCODE -ne 0) { throw ('eim download failed, curl exit code ' + $LASTEXITCODE) }; \
    if ((Get-FileHash C:\eim-cli\bin\eim.exe -Algorithm SHA256).Hash -ne $env:EIM_EXE_SHA256) { throw 'eim SHA256 mismatch' }
RUN [Environment]::SetEnvironmentVariable('Path', 'C:\ProgramData\chocolatey\bin;' + 'C:\eim-cli\bin;' + 'C:\cargo\bin;' + $env:Path, [EnvironmentVariableTarget]::Machine)

# Setup Jenkins User
RUN net user jenkins /add /passwordreq:no; \
    net localgroup Administrators jenkins /add; \
    New-Item -ItemType Directory -Path C:\Users\jenkins\AppData\Local\Temp -Force; \
    icacls C:\Users\jenkins /grant 'jenkins:(OI)(CI)F' /T; \
    icacls C:\TEMP /grant 'jenkins:(OI)(CI)F' /T

# jenkins' profile locations, used by eim here and by everything in the agent image.
ENV USERPROFILE="C:\Users\jenkins" \
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

# Hand back to the default administrator so the agent image's setup steps run as before.
USER ContainerAdministrator
WORKDIR C:/
