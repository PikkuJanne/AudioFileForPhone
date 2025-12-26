@echo off
setlocal

REM Drag & drop a folder onto this .bat
REM It launches AudioFileForPhone.ps1 in interactive mode (TUI + file picker).

if "%~1"=="" (
    echo Drag a folder onto this .bat to convert audio for phone.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%AudioFileForPhone.ps1"

REM Prefer pwsh if available, otherwise fall back to Windows PowerShell.
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    REM PowerShell 7+
    pwsh -NoProfile -Sta -ExecutionPolicy Bypass ^
        -File "%PS_SCRIPT%" "%~1" -Interactive
) else (
    REM Windows PowerShell 5.1
    powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass ^
        -File "%PS_SCRIPT%" "%~1" -Interactive
)

echo.
echo Done. Check the new "AudioForPhone_*" folder next to the script.
pause
