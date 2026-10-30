<#
.SYNOPSIS
    Automates cloning, patching, building, and installing a single Unreal Engine version from a Git repository.
.PARAMETER UE_GIT_TAG
    The git tag or branch to install (e.g., "5.5.4-release").
.PARAMETER GitHubToken
    Your GitHub Personal Access Token with access to the repository.
.PARAMETER UE_RepoUrl
    The Git repository URL to clone from (default: https://github.com/EpicGames/UnrealEngine.git).
.PARAMETER UE_BUILDGRAPH_EXTRA_ARGS
    Extra BuildGraph arguments passed to the engine build.
.PARAMETER UERoot
    Root directory where the engine will be installed (default: C:\UnrealEngine).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UE_GIT_TAG,

    [Parameter(Mandatory = $true)]
    [SecureString]$GitHubToken,

    [Parameter(Mandatory = $false)]
    [string]$UE_RepoUrl = "https://github.com/EpicGames/UnrealEngine.git",

    [Parameter(Mandatory = $false)]
    [string]$UE_BUILDGRAPH_EXTRA_ARGS = "",

    [Parameter(Mandatory = $false)]
    [string]$UERoot = "C:\UnrealEngine"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Ensure script is run as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Convert SecureString token to plain text for headers and git
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GitHubToken)
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

# Environment variables matching build configuration behavior
$env:MSBUILDDISABLENODEREUSE = "1"
$env:DOTNET_CLI_USE_MSBUILD_SERVER = "0"
$env:UseSharedCompilation = "false"

$tempDir = "C:\TEMP"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$buildConfigPath = Join-Path $tempDir "BuildConfiguration.xml"

if (-not (Test-Path $buildConfigPath)) {
@"
<?xml version="1.0" encoding="utf-8"?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
  <!-- UnrealBuildTool Configuration -->
</Configuration>
"@ | Out-File -FilePath $buildConfigPath -Encoding utf8
}

$dest = Join-Path $UERoot $UE_GIT_TAG
Write-Host "=== Building Unreal Engine $UE_GIT_TAG from $UE_RepoUrl into $dest ===" -ForegroundColor Cyan

if (Test-Path $dest) { 
    throw "$dest already exists. Remove it or choose a different version." 
}

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:' + $plainToken))
New-Item -ItemType Directory -Path $UERoot -Force | Out-Null

# Clone repository
Write-Host "Cloning repository (depth 1, branch $UE_GIT_TAG from $UE_RepoUrl)..." -ForegroundColor Yellow
& 'C:\Program Files\Git\cmd\git.exe' -c core.longpaths=true -c ("http.extraHeader=Authorization: Basic " + $auth) `
    clone --depth 1 --branch $UE_GIT_TAG $UE_RepoUrl C:\UE
if ($LASTEXITCODE -ne 0) { 
    throw "git clone failed with exit code $LASTEXITCODE" 
}

Set-Location C:\UE

# Patch Setup.bat to prevent interactive prompts or hanging blocks
Write-Host "Patching Setup.bat..." -ForegroundColor Yellow
(Get-Content Setup.bat) -replace '^(.*(PrereqSetup|UnrealVersionSelector).*)$', 'rem $1' | Set-Content Setup.bat -Encoding ascii

# Run Setup.bat
Write-Host "Running Setup.bat..." -ForegroundColor Yellow
& cmd /c Setup.bat --force --exclude=Android --exclude=Linux --exclude=LinuxArm64 --exclude=Mac
if ($LASTEXITCODE -ne 0) { 
    throw "Setup.bat failed with exit code $LASTEXITCODE" 
}

if (-not (Test-Path C:\UE\Engine\Source\Programs\AutomationTool\IOS\Resources\GreenCheck.png)) { 
    throw "AutomationTool IOS resources missing after Setup.bat; IOS dependencies must not be excluded." 
}

# Install Prerequisites
Write-Host "Installing engine prerequisites (UEPrereqSetup_x64.exe)..." -ForegroundColor Cyan
$prereq = Start-Process -FilePath C:\UE\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe -ArgumentList '/quiet','/norestart' -PassThru
$null = $prereq.Handle
if (-not $prereq.WaitForExit(1800000)) { 
    $prereq.Kill()
    throw "UEPrereqSetup_x64.exe was still running after 30 minutes." 
}
if ($prereq.ExitCode -notin 0, 3010) { 
    Write-Warning ("UEPrereqSetup_x64.exe exited with code " + $prereq.ExitCode) 
}

# Verify InstalledEngineBuild.xml options
$xmlPath = "Engine\Build\InstalledEngineBuild.xml"
if (-not (Test-Path $xmlPath)) {
    throw "InstalledEngineBuild.xml not found in repository."
}
$xml = Get-Content $xmlPath -Raw
foreach ($opt in 'BuiltDirectory','WithDDC','WithServer','WithClient','GameConfigurations','WithWin64','WithLinux','WithLinuxArm64','WithAndroid','WithMac','WithIOS','WithTVOS') {
    if ($xml -notmatch ('<Option\s+Name=.' + $opt + '.')) { 
        throw "InstalledEngineBuild.xml has no $opt option; update the BuildGraph -set list." 
    }
}

$armOptions = @([regex]::Matches($xml, '<Option\s+Name=.(With\w*Win\w*Arm64\w*).') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
if ($armOptions) { 
    Write-Host ("Enabling Windows ARM64 options: " + ($armOptions -join ', ')) -ForegroundColor Green
} else { 
    Write-Warning "No Windows ARM64 installed-build option found, defaulting to x64 Win64 binaries." 
}

$setArgs = @(
    '-set:BuiltDirectory=C:\LocalBuilds', 
    '-set:WithDDC=false', 
    '-set:WithServer=false', 
    '-set:WithClient=false', 
    '-set:GameConfigurations=Development;Shipping', 
    '-set:WithWin64=true', 
    '-set:WithLinux=false', 
    '-set:WithLinuxArm64=false', 
    '-set:WithAndroid=false', 
    '-set:WithMac=false', 
    '-set:WithIOS=false', 
    '-set:WithTVOS=false'
) + @($armOptions | ForEach-Object { '-set:' + $_ + '=true' }) + @($UE_BUILDGRAPH_EXTRA_ARGS -split ' ' | Where-Object { $_ })

New-Item -ItemType Directory -Path Engine\Saved\UnrealBuildTool -Force | Out-Null
Copy-Item $buildConfigPath Engine\Saved\UnrealBuildTool\BuildConfiguration.xml

# Run BuildGraph with retry loop
for ($attempt = 1; ; $attempt++) {
    Write-Host "Starting BuildGraph execution (Attempt $attempt/10)..." -ForegroundColor Cyan
    & .\Engine\Build\BatchFiles\RunUAT.bat BuildGraph '-script=Engine/Build/InstalledEngineBuild.xml' '-target=Make Installed Build Win64' @setArgs
    $rc = $LASTEXITCODE
    
    if ($rc -eq 0) { break }

    Get-ChildItem C:\UE\Engine\Programs\AutomationTool\Saved\Logs -Filter *.txt -ErrorAction SilentlyContinue |
        Select-String -Pattern ': (fatal )?error' | Select-Object -First 50 | ForEach-Object { Write-Host ($_.Filename + ': ' + $_.Line) -ForegroundColor Red }

    if ($attempt -ge 10) { 
        throw "BuildGraph failed after $attempt attempts (last exit code $rc)." 
    }
    Write-Host "BuildGraph failed with exit code $rc, retrying..." -ForegroundColor Yellow
}

if (-not (Test-Path "C:\LocalBuilds\Windows\Engine\Build\Build.version")) { 
    throw "Installed build not found in C:\LocalBuilds\Windows." 
}

# Drop PDB files to save space
Write-Host "Removing PDB files..." -ForegroundColor Yellow
Get-ChildItem C:\LocalBuilds\Windows -Recurse -Filter *.pdb -File | Remove-Item -Force -ErrorAction Continue

# Move output to destination
Write-Host "Moving build files to destination: $dest" -ForegroundColor Green
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Move-Item C:\LocalBuilds\Windows $dest

Set-Location C:\

# Cleanup source directory safely handling file locks
Write-Host "Cleaning up build directories and stopping lingering processes..." -ForegroundColor Yellow
for ($attempt = 1; Test-Path C:\UE; $attempt++) {
    Get-Process | Where-Object { $_.Path -like 'C:\UE\*' } | ForEach-Object { 
        Write-Host "Stopping process PID $($_.Id)"
        $_.Kill()
        $_.WaitForExit(30000) | Out-Null 
    }
    cmd /c rmdir /s /q \\?\C:\UE
    if (-not (Test-Path C:\UE)) { break }
    if ($attempt -ge 5) { 
        throw "Could not delete C:\UE after building." 
    }
    Start-Sleep -Seconds 10
}

# Clear local caches
@('C:\LocalBuilds', (Join-Path $env:USERPROFILE '.nuget'), (Join-Path $env:LOCALAPPDATA 'UnrealEngine'), (Join-Path $env:LOCALAPPDATA 'UnrealBuildTool')) |
    Where-Object { Test-Path $_ } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Unreal Engine build from $UE_RepoUrl ($UE_GIT_TAG) completed successfully!" -ForegroundColor Green