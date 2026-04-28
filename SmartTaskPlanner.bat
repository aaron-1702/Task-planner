@echo off
setlocal
title Smart Task Planner

set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
set "APP_DIR=C:\Users\aaron\Desktop\Apps\smart_task_planner"

REM ── Supabase Keys hier eintragen ─────────────────────────────────────────────
set "SUPABASE_URL=https://pcsngbgxkristsqexgkw.supabase.co"
set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjc25nYmd4a3Jpc3RzcWV4Z2t3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczODIyMTMsImV4cCI6MjA5Mjk1ODIxM30.UBwpVsI_1xWVE5xcfwY7wXWWvd3PuMa9x4EYz8c9oZY"
set "BUILD_DIR=%APP_DIR%\build\web"
set "PORT=8080"

set "PATH=%PATH%;%FLUTTER_BIN%"

REM ── Beim ersten Start: App automatisch bauen ─────────────────────────────────
if not exist "%BUILD_DIR%\index.html" (
    echo Erster Start - App wird gebaut, bitte warten...
    echo.
    cd /d "%APP_DIR%"
    call flutter build web --release ^
        --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
        --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
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
