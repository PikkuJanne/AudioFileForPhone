@echo off
setlocal DisableDelayedExpansion

REM Existing-tool setup only. Use the PS1 directly for explicit directory/config options.
set "SETUP_SCRIPT=%~dp0Setup-AudioFileForPhone.ps1"
set "SETUP_HOST=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "SETUP_HOST=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not "%~1"=="" goto invalid_arguments
REM A quoted empty argument is still an argument, including before extra arguments.
if not "%1"=="" goto invalid_arguments
if not exist "%SETUP_SCRIPT%" goto missing_script
if not exist "%SETUP_HOST%" goto missing_host

REM Trusted unsigned app: process-only request; managed policy remains authoritative.
REM No host fallback, script-text evaluation or retry after setup begins.
REM Keep inherited PowerShell 7 modules out of the built-in Windows PowerShell host.
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SETUP_HOST%" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"
set "CHILD_EXIT=%ERRORLEVEL%"
goto finish

:invalid_arguments
echo This setup launcher accepts no arguments. Run Setup-AudioFileForPhone.ps1 directly for command-line options.
set "CHILD_EXIT=1"
goto finish

:missing_script
echo Required Setup-AudioFileForPhone.ps1 is missing. Restore the complete application package.
echo [DIAGNOSTIC] stage=Bootstrap; code=HelperMissing.
set "CHILD_EXIT=1"
goto finish

:missing_host
echo Built-in x64 Windows PowerShell could not be found. Open an allowed x64 STA PowerShell host and run Setup-AudioFileForPhone.ps1.
echo [DIAGNOSTIC] stage=Bootstrap; code=HostStartFailed.
set "CHILD_EXIT=1"

:finish
echo.
echo AudioFileForPhone setup exit code: %CHILD_EXIT%
if "%CHILD_EXIT%"=="1" echo Setup failed or no tools were selected. Read the error above and any reported local log.
if "%CHILD_EXIT%"=="130" echo Setup was cancelled.
REM Preserve the child result even when its unsigned PS1 never entered.
pause
exit /b %CHILD_EXIT%
