@echo off
setlocal DisableDelayedExpansion

REM Existing-tool setup only. Use the PS1 directly for explicit directory/config options.
set "SETUP_SCRIPT=%~dp0Setup-AudioFileForPhone.ps1"
set "SETUP_HOST=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not "%~1"=="" goto invalid_arguments
REM A quoted empty argument is still an argument, including before extra arguments.
if not "%1"=="" goto invalid_arguments
if not exist "%SETUP_SCRIPT%" goto missing_script
if not exist "%SETUP_HOST%" goto missing_host

REM RemoteSigned is a process-only request. Enforced organization policy still wins.
REM There is no host fallback after setup begins.
"%SETUP_HOST%" -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%SETUP_SCRIPT%"
set "CHILD_EXIT=%ERRORLEVEL%"
goto finish

:invalid_arguments
echo This setup launcher accepts no arguments. Run Setup-AudioFileForPhone.ps1 directly for command-line options.
set "CHILD_EXIT=1"
goto finish

:missing_script
echo Required Setup-AudioFileForPhone.ps1 is missing. Restore the complete application package.
set "CHILD_EXIT=1"
goto finish

:missing_host
echo Windows PowerShell could not be found. Open an allowed PowerShell host and run Setup-AudioFileForPhone.ps1.
set "CHILD_EXIT=1"

:finish
REM Preserve the setup result. A redirected caller never waits for a key.
if not exist "%SETUP_HOST%" exit /b %CHILD_EXIT%
"%SETUP_HOST%" -NoProfile -Command "try { if (-not [Console]::IsInputRedirected) { Write-Host 'Press any key to close.'; $null = [Console]::ReadKey($true) } } catch { }"
exit /b %CHILD_EXIT%
