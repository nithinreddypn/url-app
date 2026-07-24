[CmdletBinding()]
param(
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"

if (-not (Test-Path -LiteralPath $adb)) {
    throw "Android Debug Bridge was not found in the configured Android SDK."
}

$connected = @(
    & $adb devices |
        Select-Object -Skip 1 |
        Where-Object { $_ -match "\tdevice$" } |
        ForEach-Object { ($_ -split "\s+")[0] }
)

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    if ($connected.Count -ne 1) {
        throw "Connect exactly one Android device, or pass -DeviceId with a connected device ID."
    }
    $DeviceId = $connected[0]
} elseif ($connected -notcontains $DeviceId) {
    throw "The selected Android device is not connected."
}

$isEmulator = ((& $adb -s $DeviceId shell getprop ro.kernel.qemu) -join "").Trim() -eq "1"

if ($isEmulator) {
    $apiBaseUrl = "http://10.0.2.2:8123/api/v1"
} else {
    # Forward the phone's loopback port to the development computer. This is
    # more reliable than LAN discovery and avoids public-network firewall rules.
    & $adb -s $DeviceId reverse "tcp:8123" "tcp:8123"
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create the Android-to-PC API connection."
    }
    $apiBaseUrl = "http://127.0.0.1:8123/api/v1"
}

Write-Host "Starting Flutter for $DeviceId using the local development API."
Push-Location $projectRoot
try {
    & flutter run -d $DeviceId "--dart-define=API_BASE_URL=$apiBaseUrl"
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
