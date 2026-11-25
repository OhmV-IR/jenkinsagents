param([Parameter(Mandatory)][string]$BufMajor)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base  = 'https://github.com/bufbuild/buf/releases/latest/download'
$asset = 'buf-Windows-x86_64.exe'
$tmp   = Join-Path $env:TEMP 'buf-dl'
New-Item -ItemType Directory -Force -Path $tmp, 'C:\buf' | Out-Null

function Get-File($uri, $out) {
    for ($i = 1; $i -le 5; $i++) {
        try { Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $out; return }
        catch { if ($i -eq 5) { throw }; Start-Sleep -Seconds 2 }
    }
}

Get-File "$base/$asset" "$tmp\$asset"
Get-File "$base/sha256.txt" "$tmp\sha256.txt"

$line = Get-Content "$tmp\sha256.txt" |
    Where-Object { $_ -match (' ' + [regex]::Escape($asset) + '$') } |
    Select-Object -First 1
if (-not $line) { throw "No checksum entry for $asset" }
$expected = ($line -split '\s+')[0]
$actual   = (Get-FileHash -Algorithm SHA256 "$tmp\$asset").Hash
if ($actual -ne $expected) { throw "Checksum mismatch: expected $expected, got $actual" }

Move-Item "$tmp\$asset" 'C:\buf\buf.exe'
Remove-Item -Recurse -Force $tmp

$version = (& 'C:\buf\buf.exe' --version).Trim()
if (-not $version.StartsWith("$BufMajor.")) {
    throw "ERROR: latest buf is $version, expected $BufMajor.x; bump BUF_MAJOR"
}
