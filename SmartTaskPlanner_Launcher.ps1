$ErrorActionPreference = 'SilentlyContinue'

$FLUTTER_BIN = "$env:USERPROFILE\flutter\bin"
$APP_DIR     = "C:\Users\aaron\Desktop\Apps\smart_task_planner"
$BUILD_DIR   = "$APP_DIR\build\web"
$PORT        = 8080
$PROFILE_DIR = "$env:APPDATA\SmartTaskPlanner\ChromeProfile"

$env:PATH += ";$FLUTTER_BIN"

# ── Beim ersten Start: App bauen ─────────────────────────────────────────────
if (-not (Test-Path "$BUILD_DIR\index.html")) {
    Set-Location $APP_DIR
    & flutter build web --release `
        "--dart-define=SUPABASE_URL=https://placeholder.supabase.co" `
        "--dart-define=SUPABASE_ANON_KEY=placeholder" | Out-Null
}

# ── Alten Server auf Port beenden ────────────────────────────────────────────
Get-NetTCPConnection -LocalPort $PORT | ForEach-Object {
    Stop-Process -Id $_.OwningProcess -Force
}

# ── dhttpd installieren falls nicht vorhanden ────────────────────────────────
$installed = & dart pub global list 2>$null
if ($installed -notmatch 'dhttpd') {
    & dart pub global activate dhttpd | Out-Null
}

# ── Server starten ────────────────────────────────────────────────────────────
$serverProc = Start-Process `
    -FilePath "dart" `
    -ArgumentList "pub", "global", "run", "dhttpd", "--path", $BUILD_DIR, "--port", $PORT `
    -WindowStyle Hidden `
    -PassThru

# ── Warten bis Server bereit ──────────────────────────────────────────────────
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    try {
        $null = Invoke-WebRequest "http://localhost:$PORT" -UseBasicParsing -TimeoutSec 1
        $ready = $true; break
    } catch {
        [System.Threading.Thread]::Sleep(500)
    }
}

# ── Chrome-Pfad ermitteln ─────────────────────────────────────────────────────
$chromeCandidates = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chrome = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
    # Kein Chrome gefunden: normaler Browser-Tab als Fallback
    Start-Process "http://localhost:$PORT"
    $serverProc.WaitForExit()
    exit
}

# ── Dediziertes App-Profil anlegen (Daten bleiben erhalten) ──────────────────
New-Item -ItemType Directory -Force -Path $PROFILE_DIR | Out-Null

# ── App-Fenster starten und auf Schließen warten ─────────────────────────────
$appProc = Start-Process `
    -FilePath $chrome `
    -ArgumentList `
        "--app=http://localhost:$PORT", `
        "--user-data-dir=`"$PROFILE_DIR`"", `
        "--window-size=1280,800" `
    -PassThru

$appProc.WaitForExit()

# ── Server beenden wenn App geschlossen ──────────────────────────────────────
Stop-Process -Id $serverProc.Id -Force
Get-NetTCPConnection -LocalPort $PORT | ForEach-Object {
    Stop-Process -Id $_.OwningProcess -Force
}
