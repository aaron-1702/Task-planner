@echo off
setlocal
title Smart Task Planner - Build

set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
set "APP_DIR=C:\Users\aaron\Desktop\Apps\smart_task_planner"

REM ── Supabase Keys hier eintragen ─────────────────────────────────────────────
set "SUPABASE_URL=https://pcsngbgxkristsqexgkw.supabase.co"
set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjc25nYmd4a3Jpc3RzcWV4Z2t3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczODIyMTMsImV4cCI6MjA5Mjk1ODIxM30.UBwpVsI_1xWVE5xcfwY7wXWWvd3PuMa9x4EYz8c9oZY"
set "PATH=%PATH%;%FLUTTER_BIN%"

echo ============================================
echo   Smart Task Planner - App bauen
echo ============================================
echo.
echo (Bitte warten, das dauert ca. 30-60 Sekunden)
echo.

cd /d "%APP_DIR%"
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
