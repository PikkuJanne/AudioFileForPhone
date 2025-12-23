@echo off
setlocal

REM Drag & drop a folder onto this .bat
REM It will call AudioFileForPhone.ps1 with that folder as InputFolder.

if "%~1"=="" (
    echo Drag a folder onto this .bat to convert audio for phone.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%AudioFileForPhone.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -File "%PS_SCRIPT%" "%~1"

echo.
echo Done. Check the new "AudioForPhone_*" folder next to the script.
pause
