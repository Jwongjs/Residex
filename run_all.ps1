<#
    run_all.ps1  -  Launch the full Documind stack:
       1. FastAPI backend  (http://localhost:8000)
       2. Android emulator (lightweight AVD "documind_light")
       3. Flutter app on that emulator

    Usage:
       Right-click -> Run with PowerShell, or:
       powershell -ExecutionPolicy Bypass -File run_all.ps1

    The script is idempotent: if the backend / emulator are already
    running it reuses them instead of starting duplicates.
#>

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------- paths
$Root       = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackendDir = Join-Path $Root "backend"
$AppDir     = Join-Path $Root "residex_app"
$VenvPy     = Join-Path $Root ".venv\Scripts\python.exe"
$Sdk        = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb        = Join-Path $Sdk "platform-tools\adb.exe"
$Emulator   = Join-Path $Sdk "emulator\emulator.exe"
$Avd        = "documind_light"
$Port       = 8000

# Android SDK location for child processes
$env:ANDROID_HOME     = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

# ---- JAVA_HOME must point at the JDK ROOT (not \bin) or Gradle fails ----
$JdkCandidates = @(
    "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot",
    (Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-17*" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName)
) | Where-Object { $_ -and (Test-Path (Join-Path $_ "bin\java.exe")) }

if ($JdkCandidates.Count -gt 0) {
    $env:JAVA_HOME = $JdkCandidates[0]
    $env:Path      = (Join-Path $env:JAVA_HOME "bin") + ";" + $env:Path
    Write-Host "JAVA_HOME -> $env:JAVA_HOME" -ForegroundColor DarkGray
} else {
    Write-Warning "No Adoptium JDK 17 found; relying on Gradle's own JDK discovery."
}

function Test-BackendUp {
    try {
        $r = Invoke-WebRequest "http://127.0.0.1:$Port/health" -TimeoutSec 3 -UseBasicParsing
        return $r.StatusCode -eq 200
    } catch { return $false }
}

# ---------------------------------------------------------- 1. backend
Write-Host "`n==> [1/3] Backend" -ForegroundColor Cyan
if (Test-BackendUp) {
    Write-Host "Backend already healthy on :$Port - reusing it." -ForegroundColor Green
} else {
    $py = if (Test-Path $VenvPy) { $VenvPy } else { "python" }
    Write-Host "Starting backend with: $py"
    Start-Process -FilePath $py `
        -ArgumentList "-m","uvicorn","main:app","--host","0.0.0.0","--port","$Port" `
        -WorkingDirectory $BackendDir
    Write-Host -NoNewline "Waiting for backend"
    for ($i = 0; $i -lt 60; $i++) {
        if (Test-BackendUp) { break }
        Start-Sleep -Seconds 2; Write-Host -NoNewline "."
    }
    if (Test-BackendUp) { Write-Host " up!" -ForegroundColor Green }
    else { Write-Warning " backend did not become healthy in time (check its window)." }
}

# --------------------------------------------------------- 2. emulator
Write-Host "`n==> [2/3] Android emulator" -ForegroundColor Cyan
$emuId = (& $Adb devices | Select-String -Pattern "^(emulator-\d+)\s+device$" |
          ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)

if ($emuId) {
    Write-Host "Emulator already running ($emuId) - reusing it." -ForegroundColor Green
} else {
    Write-Host "Booting AVD '$Avd' ..."
    Start-Process -FilePath $Emulator -ArgumentList "-avd",$Avd,"-gpu","auto","-no-boot-anim"
    & $Adb wait-for-device
    Write-Host -NoNewline "Waiting for full boot"
    do {
        Start-Sleep -Seconds 2; Write-Host -NoNewline "."
        $booted = (& $Adb shell getprop sys.boot_completed 2>$null)
    } while (("$booted").Trim() -ne "1")
    Write-Host " booted!" -ForegroundColor Green
    $emuId = (& $Adb devices | Select-String -Pattern "^(emulator-\d+)\s+device$" |
              ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)
}

# ----------------------------------------------------------- 3. flutter
Write-Host "`n==> [3/3] Flutter app on $emuId" -ForegroundColor Cyan
Write-Host "(first build is slow; press 'q' in this window to stop the app)`n"
Push-Location $AppDir
try {
    flutter run -d $emuId
} finally {
    Pop-Location
}
