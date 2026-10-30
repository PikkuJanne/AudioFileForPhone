@echo off
setlocal DisableDelayedExpansion

REM Transport the folder once as data; never CALL or build PowerShell command text.
set "AUDIOFILEFORPHONE_INPUT=%~1"
set "AFP_SCRIPT=%~dp0AudioFileForPhone.ps1"
set "AFP_HOST=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "AFP_HOST=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" goto invalid_arguments
if not "%~2"=="" goto invalid_arguments
REM A quoted empty second argument is still an extra argument.
if not "%2"=="" goto invalid_arguments
if not exist "%AFP_SCRIPT%" goto missing_script
if not exist "%AFP_HOST%" goto missing_host

REM Trusted unsigned app: process-only request; managed policy remains authoritative.
REM One host, one converter invocation. Never retry after an error or policy refusal.
REM A PowerShell 7 caller may export incompatible module paths; use this host's modules.
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%AFP_HOST%" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%AFP_SCRIPT%" -FromBatchLauncher
set "CHILD_EXIT=%ERRORLEVEL%"
goto finish

:invalid_arguments
echo Drop exactly one audio folder onto AudioFileForPhone.bat or its shortcut.
echo Keep the complete application together. Startup errors remain above this message.
set "CHILD_EXIT=1"
goto finish

:missing_script
echo Required AudioFileForPhone.ps1 is missing. Restore the complete application package.
echo [DIAGNOSTIC] stage=Bootstrap; code=HelperMissing.
set "CHILD_EXIT=1"
goto finish

:missing_host
echo Built-in x64 Windows PowerShell could not be found. Restore Windows PowerShell or use an allowed x64 STA host directly.
echo [DIAGNOSTIC] stage=Bootstrap; code=HostStartFailed.
set "CHILD_EXIT=1"

:finish
echo.
echo AudioFileForPhone exit code: %CHILD_EXIT%
if "%CHILD_EXIT%"=="1" echo The operation failed. Read the error above and any reported local log.
if "%CHILD_EXIT%"=="2" echo Some files failed. Read the summary and local log above.
if "%CHILD_EXIT%"=="130" echo The operation was cancelled.
REM CMD owns visibility even if PowerShell could not load or parse any script.
pause
exit /b %CHILD_EXIT%
