@echo off
setlocal
title Smart Task Planner - Build

set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
set "APP_DIR=C:\Users\aaron\Desktop\Apps\smart_task_planner"
set "PATH=%PATH%;%FLUTTER_BIN%"

echo ============================================
echo   Smart Task Planner - App bauen
echo ============================================
echo.
echo (Bitte warten, das dauert ca. 30-60 Sekunden)
echo.

cd /d "%APP_DIR%"
call flutter build web --release ^
    --dart-define=SUPABASE_URL=https://placeholder.supabase.co ^
    --dart-define=SUPABASE_ANON_KEY=placeholder

if errorlevel 1 (
    echo.
    echo FEHLER: Build fehlgeschlagen!
) else (
    echo.
    echo Build erfolgreich! Starte die App mit SmartTaskPlanner.bat
)

pause
endlocal
