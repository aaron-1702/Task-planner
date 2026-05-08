@echo off
setlocal
title Smart Task Planner - Build

set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
set "APP_DIR=C:\Users\aaron\Desktop\Apps\smart_task_planner"

REM ── Supabase Keys aus .env laden ─────────────────────────────────────────────
if not exist "%APP_DIR%\.env" (
    echo FEHLER: .env Datei nicht gefunden! Bitte .env.example kopieren und ausfuellen.
    pause
    exit /b 1
)
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%APP_DIR%\.env") do (
    if not "%%A"=="" set "%%A=%%B"
)
set "PATH=%PATH%;%FLUTTER_BIN%"

echo ============================================
echo   Smart Task Planner - App bauen
echo ============================================
echo.
echo (Bitte warten, das dauert ca. 30-60 Sekunden)
echo.

cd /d "%APP_DIR%"

echo Aktualisiere App-Icons...
call dart run flutter_launcher_icons >nul
if errorlevel 1 (
    echo.
    echo FEHLER: Icon-Generierung fehlgeschlagen!
    pause
    exit /b 1
)

call flutter build web --release ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if errorlevel 1 (
    echo.
    echo FEHLER: Build fehlgeschlagen!
) else (
    echo.
    echo Build erfolgreich! Starte die App mit SmartTaskPlanner.bat
)

pause
endlocal
