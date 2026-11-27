param(
    # Default to her watch, the Forerunner 970 (454x454 AMOLED). Use -Device fr265 to
    # build the 416x416 variant, fr165 for 390x390, fr265s for 360x360.
    [string]$Device = "fr970",
    [switch]$Run,
    [switch]$Export
)

# Load local build configuration or create default if missing
$configFile = Join-Path $PSScriptRoot "build_config.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
    $JavaHome = $config.JavaHome
    $SdkDir = $config.SdkDir
} else {
    $JavaHome = "C:\Program Files\Android\Android Studio\jbr"
    $SdkDir = ""
}

# No SDK set (or it was removed by an SDK update): use the newest one the
# Connect IQ SDK Manager has installed.
if (!$SdkDir -or !(Test-Path (Join-Path $SdkDir "bin\monkeyc.bat"))) {
    $sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
    $newest = Get-ChildItem $sdkRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "bin\monkeyc.bat") } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($newest) {
        $SdkDir = $newest.FullName
        Write-Host "Using Connect IQ SDK: $SdkDir" -ForegroundColor Cyan
        [ordered]@{ JavaHome = $JavaHome; SdkDir = $SdkDir } | ConvertTo-Json | Out-File -Encoding utf8 $configFile
    }
}

# 1. Setup Java Environment
$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH

# 2. Define Garmin SDK Paths
$sdkBin = Join-Path $SdkDir "bin"

if (!(Test-Path (Join-Path $sdkBin "monkeyc.bat"))) {
    Write-Error "Connect IQ SDK not found at $SdkDir. Install it with the Connect IQ SDK Manager (developer.garmin.com/connect-iq/sdk), download the devices you build for, then put the SDK folder and your JDK in build_config.json."
    exit 1
}
if (!(Test-Path (Join-Path $JavaHome "bin\java.exe"))) {
    Write-Error "Java not found at $JavaHome. Install a JDK (17 or newer) and put its folder in build_config.json as JavaHome."
    exit 1
}

# 3. Create output directory if it doesn't exist
if (!(Test-Path -Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

# 4. Build the project
$monkeyc = Join-Path $sdkBin "monkeyc.bat"
$junglePath = Join-Path $PSScriptRoot "monkey.jungle"
$keyPath = Join-Path $PSScriptRoot "developer_key.der"

if ($Export) {
    Write-Host "Packaging application for Connect IQ Store (.iq)..." -ForegroundColor Cyan
    $outputPath = Join-Path $PSScriptRoot "bin\ChristmasJoy.iq"
    & $monkeyc -e -f $junglePath -o $outputPath -y $keyPath
} else {
    # monkeyc rejects the whole jungle if it names a watch whose device files
    # the SDK Manager hasn't downloaded. For a one-watch build, leave those
    # lines out (a store package still needs every device).
    $devRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Devices"
    $missing = @()
    $kept = Get-Content $junglePath | Where-Object {
        if ($_ -match '^\s*(\w+)\.resourcePath' -and $Matches[1] -ne 'base' -and !(Test-Path (Join-Path $devRoot $Matches[1]))) {
            $missing += $Matches[1]; $false
        } else { $true }
    }
    if ($missing.Count -gt 0) {
        Write-Host "Skipping watches not downloaded yet: $($missing -join ', ')" -ForegroundColor Yellow
        $junglePath = Join-Path $PSScriptRoot "build.local.jungle"
        $kept | Set-Content -Encoding utf8 $junglePath
    }

    Write-Host "Building for device: $Device..." -ForegroundColor Cyan
    $outputPath = Join-Path $PSScriptRoot "bin\ChristmasJoy.prg"
    & $monkeyc -f $junglePath -o $outputPath -y $keyPath -d $Device
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

if ($Export) {
    Write-Host "Package Succeeded! Output: bin\ChristmasJoy.iq" -ForegroundColor Green
} else {
    Write-Host "Build Succeeded! Output: bin\ChristmasJoy.prg" -ForegroundColor Green
}

# 5. Launch in Simulator if requested
if ($Run) {
    Write-Host "Checking if Simulator is running..." -ForegroundColor Cyan
    $simProcess = Get-Process -Name "simulator" -ErrorAction SilentlyContinue
    if (!$simProcess) {
        Write-Host "Starting Connect IQ Simulator..." -ForegroundColor Cyan
        $simulator = Join-Path $sdkBin "simulator.exe"
        Start-Process -FilePath $simulator
        Start-Sleep -Seconds 4 # Give it a moment to boot
    } else {
        Write-Host "Simulator is already running." -ForegroundColor Cyan
    }

    Write-Host "Deploying to $Device in simulator..." -ForegroundColor Cyan
    $monkeydo = Join-Path $sdkBin "monkeydo.bat"
    & $monkeydo $outputPath $Device
}
