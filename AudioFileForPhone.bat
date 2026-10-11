@echo off
setlocal DisableDelayedExpansion

REM Drag & drop a folder onto this .bat
REM It launches AudioFileForPhone.ps1 in interactive mode (TUI + file picker).

if "%~1"=="" goto invalid_arguments
if not "%~2"=="" goto invalid_arguments
REM A quoted empty second argument is still an extra argument.
REM Inspect its raw spelling only after the dequoted value was proved empty.
if not "%2"=="" goto invalid_arguments

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%AudioFileForPhone.ps1"

REM Prefer pwsh if available, otherwise fall back to Windows PowerShell.
where pwsh >nul 2>nul
if errorlevel 1 goto windows_powershell
pwsh -NoProfile -Sta -ExecutionPolicy Bypass ^
    -File "%PS_SCRIPT%" "%~1" -Interactive
set "CHILD_EXIT=%ERRORLEVEL%"
goto report_result

:windows_powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass ^
    -File "%PS_SCRIPT%" "%~1" -Interactive
set "CHILD_EXIT=%ERRORLEVEL%"

:report_result
echo.
if "%CHILD_EXIT%"=="0" echo Completed. Check the output and log paths printed above.
if "%CHILD_EXIT%"=="1" echo Failed. Review the error and any output or log paths printed above.
if "%CHILD_EXIT%"=="2" echo Completed with failures. Review the output and log paths printed above.
if "%CHILD_EXIT%"=="130" echo Cancelled. Completed outputs are preserved; review the paths printed above.
if "%CHILD_EXIT%"=="0" goto finish
if "%CHILD_EXIT%"=="1" goto finish
if "%CHILD_EXIT%"=="2" goto finish
if "%CHILD_EXIT%"=="130" goto finish
echo Failed with exit code %CHILD_EXIT%. Review the error printed above.

:finish
pause
exit /b %CHILD_EXIT%

:invalid_arguments
echo Drag exactly one folder onto this .bat to convert audio for phone.
echo Zero, empty or multiple folder arguments are not accepted.
pause
exit /b 1
