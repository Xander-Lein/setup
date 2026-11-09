@echo off
setlocal
chcp 65001 >nul 2>&1
cd /d "%~dp0"
set "PS_ARGS="
:parse
if "%~1"=="" goto run
if /I "%~1"=="--dry-run" set "PS_ARGS=-DryRun"
shift
goto parse
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\modules\refresh-session-settings.ps1" -RestartExplorer %PS_ARGS%
if errorlevel 1 (
    echo refresh_session failed.
    if not "%ORCHESTRATOR_NO_PAUSE%"=="1" pause
    exit /b 1
)
if "%PS_ARGS%"=="-DryRun" goto done
echo Done. Check Win+V and language tray icon.
:done
if not "%ORCHESTRATOR_NO_PAUSE%"=="1" pause
exit /b 0
