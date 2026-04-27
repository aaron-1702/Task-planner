@echo off
setlocal
title Smart Task Planner

set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
set "APP_DIR=C:\Users\aaron\Desktop\Apps\smart_task_planner"
set "BUILD_DIR=%APP_DIR%\build\web"
set "PORT=8080"

set "PATH=%PATH%;%FLUTTER_BIN%"

REM ── Beim ersten Start: App automatisch bauen ─────────────────────────────────
if not exist "%BUILD_DIR%\index.html" (
    echo Erster Start - App wird gebaut, bitte warten...
    echo.
    cd /d "%APP_DIR%"
    call flutter build web --release ^
        --dart-define=SUPABASE_URL=https://placeholder.supabase.co ^
        --dart-define=SUPABASE_ANON_KEY=placeholder
    if errorlevel 1 (
        echo.
        echo FEHLER: Build fehlgeschlagen!
        pause
        exit /b 1
    )
    echo.
)

REM ── Alten Server auf Port 8080 beenden (falls noch laufend) ──────────────────
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%a >nul 2>&1
)

REM ── Dart dhttpd installieren falls nicht vorhanden ───────────────────────────
dart pub global list 2>nul | findstr /c:"dhttpd" >nul
if errorlevel 1 (
    echo Installiere HTTP-Server einmalig...
    dart pub global activate dhttpd >nul 2>&1
)

REM ── Server im Hintergrund starten ────────────────────────────────────────────
start /min "Smart Task Planner Server" dart pub global run dhttpd --path "%BUILD_DIR%" --port %PORT%

REM ── Kurz warten bis Server bereit ist ────────────────────────────────────────
timeout /t 3 /nobreak >nul

REM ── Chrome-Pfad ermitteln ─────────────────────────────────────────────────────
set "CHROME="
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    set "CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"
) else if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    set "CHROME=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) else if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" (
    set "CHROME=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
)

REM ── App im eigenen Fenster öffnen (kein Browser-Chrome) ──────────────────────
if defined CHROME (
    start "" "%CHROME%" --app="http://localhost:%PORT%" --window-size=1280,800
) else (
    start "" "http://localhost:%PORT%"
)

endlocal
