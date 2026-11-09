@echo off
setlocal
chcp 65001 >nul 2>&1
fltmc >nul 2>&1
if errorlevel 1 (
    echo %* | findstr /I /C:"--dry-run" >nul
    if errorlevel 1 (
        echo Requesting administrator privileges...
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
        exit /b 0
    )
)
cd /d "%~dp0"
set "REPO_ROOT=%CD%"
set "PS_ARGS="

:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--dry-run" set "PS_ARGS=%PS_ARGS% -DryRun"
if /I "%~1"=="--verbose" set "PS_ARGS=%PS_ARGS% -VerboseMode"
shift
goto parse_args

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\ensure-ps1-utf8bom.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\download_desired_apps.ps1" -RepoRoot "%REPO_ROOT%" %PS_ARGS%
if errorlevel 1 goto fail
goto done

:fail
echo.
echo download_desired_apps failed.
if not "%ORCHESTRATOR_NO_PAUSE%"=="1" pause
exit /b 1

:done
if not "%ORCHESTRATOR_NO_PAUSE%"=="1" pause
exit /b 0
