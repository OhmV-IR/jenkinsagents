<#
.SYNOPSIS
    Packages an Epic Games Launcher install of Unreal Engine into the zip that windows/Dockerfile
    downloads through its UE_ARCHIVE_URL build arg.

.DESCRIPTION
    Epic only distributes the prebuilt Windows engine through the Epic Games Launcher, which cannot
    run inside a container. Install the engine once on any Windows PC with the Launcher, then run
    this script to turn that install into a zip the Windows agent image can consume.

    In the Launcher (Library > UE 5.8 > Options) deselect every target platform (Android, iOS,
    Linux, Linux Arm64, tvOS, ...): Android and Linux are built on the Linux agent instead. Keep
    "Editor symbols for debugging" off. The script refuses to package an install that still
    contains other target platforms unless -AllowExtraPlatforms is given.

    The zip is written with the tar.exe (libarchive) that ships with Windows, which supports
    Zip64 so it copes with the engine's size and file count.

.EXAMPLE
    .\New-UnrealEngineArchive.ps1 -OutFile D:\share\UnrealEngine-5.8.3-Win64.zip
#>
[CmdletBinding()]
param(
    [string]$EnginePath = 'C:\Program Files\Epic Games\UE_5.8',
    [string]$ExpectedVersion = '5.8.3',
    [string]$OutFile = (Join-Path (Get-Location) "UnrealEngine-$ExpectedVersion-Win64.zip"),
    # Keep .pdb files (only useful for debugging the engine itself, adds tens of GB).
    [switch]$IncludeDebugSymbols,
    # Package even if the install contains non-Windows target platforms.
    [switch]$AllowExtraPlatforms
)

$ErrorActionPreference = 'Stop'

if ([IO.Path]::GetExtension($OutFile) -ne '.zip') { throw "OutFile must end in .zip: $OutFile" }

$versionFile = Join-Path $EnginePath 'Engine\Build\Build.version'
if (-not (Test-Path $versionFile)) { throw "No Unreal Engine install found at '$EnginePath'" }
$v = Get-Content $versionFile -Raw | ConvertFrom-Json
$found = '{0}.{1}.{2}' -f $v.MajorVersion, $v.MinorVersion, $v.PatchVersion
if ($found -ne $ExpectedVersion) {
    throw "Engine at '$EnginePath' is $found, expected $ExpectedVersion. Update it in the Epic Games Launcher first."
}

# Target platforms the Windows agent must not carry: Android/Linux live on the Linux agent and the
# Apple platforms need a Mac host anyway.
$unwanted = 'Android', 'Linux', 'LinuxArm64', 'IOS', 'TVOS', 'VisionOS', 'Mac'
$present = foreach ($platform in $unwanted) {
    foreach ($dir in "Engine\Binaries\$platform", "Engine\Intermediate\Build\$platform", "Engine\Platforms\$platform") {
        if (Test-Path (Join-Path $EnginePath $dir)) { $platform; break }
    }
}
if ($present) {
    $message = "The install contains target platforms the Windows agent should not have: $($present -join ', '). " +
        'Deselect them in the Epic Games Launcher (UE 5.8 > Options) and let it update, or pass -AllowExtraPlatforms.'
    if ($AllowExtraPlatforms) { Write-Warning $message } else { throw $message }
}

$excludes = @()
if (-not $IncludeDebugSymbols) { $excludes += '--exclude', '*.pdb' }
$items = Get-ChildItem -Path $EnginePath -Force | ForEach-Object { $_.Name }

if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
Write-Host "Packaging UE $found from '$EnginePath' into '$OutFile' (this takes a while)..."
& "$env:SystemRoot\System32\tar.exe" -a -c -f $OutFile -C $EnginePath @excludes @items
if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with exit code $LASTEXITCODE" }

$hash = (Get-FileHash $OutFile -Algorithm SHA256).Hash
Write-Host ''
Write-Host "Created $OutFile ($([math]::Round((Get-Item $OutFile).Length / 1GB, 1)) GB)"
Write-Host "SHA256: $hash"
Write-Host 'Host it where the Windows Docker host can download it, then build with:'
Write-Host "  --build-arg UE_ARCHIVE_URL=<url> --build-arg UE_ARCHIVE_SHA256=$hash"
