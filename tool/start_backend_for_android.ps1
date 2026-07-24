[CmdletBinding()]
param(
    [int]$Port = 8123
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$php = Get-Command php -ErrorAction SilentlyContinue

if ($null -eq $php) {
    $xamppPhp = "C:\xampp\php\php.exe"
    if (Test-Path -LiteralPath $xamppPhp) {
        $phpPath = $xamppPhp
    } else {
        throw "PHP was not found. Add PHP to PATH or install XAMPP."
    }
} else {
    $phpPath = $php.Source
}

Push-Location (Join-Path $projectRoot "backend")
try {
    Write-Host "Serving the local API on all network interfaces at port $Port."
    & $phpPath -S "0.0.0.0:$Port" -t public public/index.php
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
