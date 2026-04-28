$ErrorActionPreference = 'SilentlyContinue'

$FLUTTER_BIN = "$env:USERPROFILE\flutter\bin"
$APP_DIR     = "C:\Users\aaron\Desktop\Apps\smart_task_planner"
$BUILD_DIR   = "$APP_DIR\build\web"
$PORT        = 8080
$PROFILE_DIR = "$env:APPDATA\SmartTaskPlanner\ChromeProfile"

# ── Supabase Keys hier eintragen ───────────────────────────────────────────
$SUPABASE_URL      = "https://pcsngbgxkristsqexgkw.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjc25nYmd4a3Jpc3RzcWV4Z2t3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczODIyMTMsImV4cCI6MjA5Mjk1ODIxM30.UBwpVsI_1xWVE5xcfwY7wXWWvd3PuMa9x4EYz8c9oZY"

$env:PATH += ";$FLUTTER_BIN"

# ── Beim ersten Start: App bauen ─────────────────────────────────────────────
if (-not (Test-Path "$BUILD_DIR\index.html")) {
    Set-Location $APP_DIR
    & flutter build web --release `
        "--dart-define=SUPABASE_URL=$SUPABASE_URL" `
        "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" | Out-Null
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

# ── Profil-Cache leeren wenn neuer Build erkannt ─────────────────────────────
# Build-ID = Hash der main.dart.js (ändert sich bei jedem neuen Build)
$mainJs = "$BUILD_DIR\main.dart.js"
$buildIdFile  = "$PROFILE_DIR\.last_build_id"
$currentBuildId = if (Test-Path $mainJs) {
    (Get-FileHash $mainJs -Algorithm MD5).Hash
} else { "unknown" }
$cachedBuildId = if (Test-Path $buildIdFile) { Get-Content $buildIdFile -Raw } else { "" }

if ($currentBuildId.Trim() -ne $cachedBuildId.Trim()) {
    # Service-Worker und Cache löschen, Login-Daten bleiben erhalten
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Service Worker" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Cache"          -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Code Cache"     -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\GPUCache"       -ErrorAction SilentlyContinue
    # Neue Build-ID speichern
    New-Item -ItemType Directory -Force -Path $PROFILE_DIR | Out-Null
    Set-Content -Path $buildIdFile -Value $currentBuildId
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
