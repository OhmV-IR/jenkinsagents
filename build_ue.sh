#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# CONFIGURATION & PARAMETERS
# ==========================================
UE_GIT_TAG="${UE_GIT_TAG:-5.5.4-release}"
UE_REPO_URL="${UE_REPO_URL:-https://github.com/EpicGames/UnrealEngine.git}"
UE_BUILDGRAPH_EXTRA_ARGS="${UE_BUILDGRAPH_EXTRA_ARGS:-}"
UE_ROOT="${UE_ROOT:-/opt/UnrealEngine}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Ensure a GitHub token is provided
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "[-] ERROR: GITHUB_TOKEN environment variable or argument is required." >&2
    echo "Usage: GITHUB_TOKEN=ghp_xxx UE_GIT_TAG=5.5.4-release ./Build-UnrealEngine-Linux.sh" >&2
    exit 1
fi

# Ensure script is run as root (to handle /opt and user mapping)
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (or with sudo)." >&2
    exit 1
fi

# ==========================================
# 1. DEPENDENCIES & ANDROID TOOLCHAIN SETUP
# ==========================================
echo "[+] Setting up Android toolchain and environment..."

export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_SDK_ROOT="/opt/android-sdk"
export NDKROOT="/opt/android-sdk/ndk/25.1.8937393"
export NDK_ROOT="/opt/android-sdk/ndk/25.1.8937393"
export ANDROID_NDK_ROOT="/opt/android-sdk/ndk/25.1.8937393"

ANDROID_CMDLINE_TOOLS_BUILD="15859902"
ANDROID_CMDLINE_TOOLS_SHA256="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"

# Install base packages if missing
apt-get update
apt-get install -y --no-install-recommends build-essential curl unzip git openjdk-17-jdk openjdk-21-jdk

# Install Android Command-Line Tools & SDK components
mkdir -p "${ANDROID_HOME}/cmdline-tools"
if [ ! -f "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "[+] Downloading Android Command-Line Tools..."
    curl -fSL --retry 5 -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"
    
    echo "${ANDROID_CMDLINE_TOOLS_SHA256}  /tmp/cmdline-tools.zip" | sha256sum -c -
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools
    mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest"
    rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip
fi

sdkmanager="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"

yes | "${sdkmanager}" --licenses > /dev/null || true
"${sdkmanager}" --install \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "ndk;25.1.8937393"

test -f "${NDKROOT}/source.properties"
grep -q '^Pkg.Revision = 25\.1\.' "${NDKROOT}/source.properties"

# Ensure a 'jenkins' build user exists
if ! id "jenkins" &>/dev/null; then
    useradd -ms /bin/bash jenkins
fi
chown -R jenkins:jenkins "${ANDROID_HOME}"

# Revert JAVA_HOME back to Java 17 for Unreal Build Tool
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

# ==========================================
# 2. PREPARE BUILD CONFIGURATION FILE
# ==========================================
BUILD_CONFIG_PATH="/home/jenkins/ue-BuildConfiguration.xml"
mkdir -p /home/jenkins

cat << 'EOF' > "${BUILD_CONFIG_PATH}"
<?xml version="1.0" encoding="utf-8"?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
  <!-- UnrealBuildTool Configuration -->
</Configuration>
EOF
chown jenkins:jenkins "${BUILD_CONFIG_PATH}"

# ==========================================
# 3. BUILD PROCESS FOR UE_GIT_TAG
# ==========================================
mkdir -p "${UE_ROOT}"
chown jenkins:jenkins "${UE_ROOT}"

# Run engine build safely as the 'jenkins' user
sudo -u jenkins env \
    JAVA_HOME="${JAVA_HOME}" \
    ANDROID_HOME="${ANDROID_HOME}" \
    ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}" \
    NDKROOT="${NDKROOT}" \
    NDK_ROOT="${NDK_ROOT}" \
    ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}" \
    UE_GIT_TAG="${UE_GIT_TAG}" \
    UE_REPO_URL="${UE_REPO_URL}" \
    UE_BUILDGRAPH_EXTRA_ARGS="${UE_BUILDGRAPH_EXTRA_ARGS}" \
    UE_ROOT="${UE_ROOT}" \
    GITHUB_TOKEN="${GITHUB_TOKEN}" \
    bash << 'EOF'
set -euo pipefail

[ -n "${UE_GIT_TAG}" ] || { echo "ERROR: UE_GIT_TAG is empty" >&2; exit 1; }

dest="${UE_ROOT}/${UE_GIT_TAG}"
if [ -e "${dest}" ]; then
    echo "ERROR: ${dest} already exists. Remove it or specify a different version." >&2
    exit 1
fi

auth="$(printf 'x-access-token:%s' "${GITHUB_TOKEN}" | base64 -w0)"
git_deps_cache="/home/jenkins/.ue-gitdeps"
mkdir -p "${git_deps_cache}"

cd /home/jenkins

# Clean up any previous runs
rm -rf UnrealEngine-src LocalBuilds

echo "=== Building Unreal Engine ${UE_GIT_TAG} from ${UE_REPO_URL} into ${dest} ==="
echo "[+] Cloning repository..."
git -c http.extraHeader="Authorization: Basic ${auth}" \
    clone --depth 1 --branch "${UE_GIT_TAG}" "${UE_REPO_URL}" UnrealEngine-src

cd UnrealEngine-src

echo "[+] Running Setup.sh..."
./Setup.sh --cache="${git_deps_cache}" \
    --exclude=Win32 --exclude=Win64 --exclude=Mac

xml="Engine/Build/InstalledEngineBuild.xml"
for opt in BuiltDirectory WithDDC WithServer WithClient GameConfigurations WithLinux WithLinuxArm64 WithAndroid WithWin64 WithMac WithIOS WithTVOS; do
    grep -q "Name=\"${opt}\"" "${xml}" || { echo "ERROR: ${xml} has no '${opt}' option; update BuildGraph" >&2; exit 1; }
done

mkdir -p Engine/Saved/UnrealBuildTool
cp /home/jenkins/ue-BuildConfiguration.xml Engine/Saved/UnrealBuildTool/BuildConfiguration.xml

attempt=1
while true; do
    echo "=== BuildGraph execution attempt ${attempt}/10 for ${UE_GIT_TAG} ==="
    if Engine/Build/BatchFiles/RunUAT.sh BuildGraph -script="${xml}" -target="Make Installed Build Linux" \
        -set:BuiltDirectory=/home/jenkins/LocalBuilds \
        -set:WithDDC=false \
        -set:WithServer=false -set:WithClient=false \
        -set:GameConfigurations='Development;Shipping' \
        -set:WithLinux=true -set:WithLinuxArm64=false -set:WithAndroid=true \
        -set:WithWin64=false -set:WithMac=false -set:WithIOS=false -set:WithTVOS=false \
        ${UE_BUILDGRAPH_EXTRA_ARGS}; then
        break
    fi

    if [ "${attempt}" -ge 10 ]; then
        echo "ERROR: BuildGraph failed after ${attempt} attempts" >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    echo "=== BuildGraph failed, retrying... ==="
done

test -f /home/jenkins/LocalBuilds/Linux/Engine/Build/Build.version

echo "[+] Cleaning up split debug symbols (*.debug)..."
find /home/jenkins/LocalBuilds/Linux -name '*.debug' -type f -delete

echo "[+] Moving build to final path: ${dest}"
mv /home/jenkins/LocalBuilds/Linux "${dest}"

cd /home/jenkins
rm -rf UnrealEngine-src LocalBuilds .nuget .config/Epic .local/share/Epic
echo "=== Successfully built and installed Unreal Engine ${UE_GIT_TAG} at ${dest} ==="
EOF

echo "[✔] Completed! Engine installed at ${UE_ROOT}/${UE_GIT_TAG}"