<#
.SYNOPSIS
    Creates a folder at a custom or default path with Administrator privileges 
    and assigns ownership to the standard interactive user.
#>

$ErrorActionPreference = "Stop"

# Ensure script is running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Please re-run PowerShell as Administrator."
    exit 1
}

# Automatically detect the current logged-in console user
$consoleUserObj = (Get-CimInstance Win32_ComputerSystem).UserName
if ($consoleUserObj) {
    $defaultUser = $consoleUserObj.Split('\')[-1]
} else {
    $defaultUser = $env:USERNAME
}

# Prompt for target user with fallback
$targetUser = Read-Host "Enter the username that should own the folder [$defaultUser]"
if ([string]::IsNullOrWhiteSpace($targetUser)) { 
    $targetUser = $defaultUser 
}

# Set default path (system-wide program files location)
$targetPath = "C:\UnrealEngine"

# Create the folder if it doesn't exist
if (-not (Test-Path $targetPath)) {
    Write-Host "Creating directory: $targetPath" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
} else {
    Write-Host "Directory already exists: $targetPath" -ForegroundColor Yellow
}

# Take ownership and grant full access to the target standard user
Write-Host "Configuring permissions for user '$targetUser'..." -ForegroundColor Cyan
Start-Process -FilePath "takeown.exe" -ArgumentList "/f `"$targetPath`" /r /d y" -NoNewWindow -Wait
Start-Process -FilePath "icacls.exe" -ArgumentList "`"$targetPath`" /grant `"${targetUser}:F`" /t" -NoNewWindow -Wait

Write-Host "Success! Folder created and assigned to $targetUser." -ForegroundColor Green