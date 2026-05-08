$ErrorActionPreference = 'SilentlyContinue'

$FLUTTER_BIN = "$env:USERPROFILE\flutter\bin"
$APP_DIR     = "C:\Users\aaron\Desktop\Apps\smart_task_planner"
$BUILD_DIR   = "$APP_DIR\build\web"
$PORT        = 8080
$PROFILE_DIR = "$env:APPDATA\SmartTaskPlanner\ChromeProfile"

# ── Supabase Keys aus .env laden ───────────────────────────────────────────
$envFile = Join-Path $APP_DIR '.env'
if (-not (Test-Path $envFile)) {
    Write-Error "FEHLER: .env Datei nicht gefunden! Bitte .env.example kopieren und ausfuellen."
    exit 1
}
Get-Content $envFile | Where-Object { $_ -match '^[^#].*=.*' } | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Variable -Name $parts[0].Trim() -Value $parts[1].Trim()
}

$env:PATH += ";$FLUTTER_BIN"

# ── Beim ersten Start: App bauen ─────────────────────────────────────────────
if (-not (Test-Path "$BUILD_DIR\index.html")) {
    Set-Location $APP_DIR
    & dart run flutter_launcher_icons | Out-Null
    if ($LASTEXITCODE -ne 0) { exit 1 }
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

# ── Profil-Cache leeren wenn neuer Build/Assets erkannt ──────────────────────
# Build-ID basiert auf main.dart.js + Web-Icons/Manifest, damit Icon-Updates
# ebenfalls einen Cache-Reset triggern.
$buildIdFile  = "$PROFILE_DIR\.last_build_id"
$buildInputs = @(
    "$BUILD_DIR\main.dart.js",
    "$BUILD_DIR\favicon.png",
    "$BUILD_DIR\manifest.json",
    "$BUILD_DIR\icons\Icon-192.png",
    "$BUILD_DIR\icons\Icon-512.png",
    "$BUILD_DIR\icons\Icon-maskable-192.png",
    "$BUILD_DIR\icons\Icon-maskable-512.png"
)

$parts = @()
foreach ($file in $buildInputs) {
    if (Test-Path $file) {
        $parts += (Get-FileHash $file -Algorithm MD5).Hash
    } else {
        $parts += "missing:$file"
    }
}
$currentBuildId = ($parts -join '|')
$cachedBuildId = if (Test-Path $buildIdFile) { Get-Content $buildIdFile -Raw } else { "" }

if ($currentBuildId.Trim() -ne $cachedBuildId.Trim()) {
    # Service-Worker und Cache löschen, Login-Daten bleiben erhalten
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Service Worker" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Web Applications" -ErrorAction SilentlyContinue
    Remove-Item -Force "$PROFILE_DIR\Default\Favicons" -ErrorAction SilentlyContinue
    Remove-Item -Force "$PROFILE_DIR\Default\Favicons-journal" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$PROFILE_DIR\Default\Shortcuts" -ErrorAction SilentlyContinue
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
