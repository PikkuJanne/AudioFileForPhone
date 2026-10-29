@echo off
setlocal DisableDelayedExpansion

REM Default no-write check. Use the PS1 directly for SelfTest/export/options.
set "AFP_CHECK_SCRIPT=%~dp0Check-AudioFileForPhone.ps1"
set "AFP_CHECK_HOST=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "AFP_CHECK_HOST=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not "%~1"=="" goto invalid_arguments
if not "%1"=="" goto invalid_arguments
if not exist "%AFP_CHECK_SCRIPT%" goto missing_script
if not exist "%AFP_CHECK_HOST%" goto missing_host
"%AFP_CHECK_HOST%" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%AFP_CHECK_SCRIPT%"
set "AFP_CHECK_EXIT=%ERRORLEVEL%"
REM Redirected callers never wait, and no arguments/user text enter this command.
"%AFP_CHECK_HOST%" -NoLogo -NoProfile -Command "try { if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) { Write-Host 'Press any key to close.'; $null = [Console]::ReadKey($true) } } catch { }"
exit /b %AFP_CHECK_EXIT%
:invalid_arguments
echo This launcher accepts no arguments. Run Check-AudioFileForPhone.ps1 for SelfTest, ExportPath or explicit tool/config options.
exit /b 1
:missing_script
echo HelperMissing: Required Check-AudioFileForPhone.ps1 is missing. Restore the complete application package.
exit /b 1
:missing_host
echo HostStartFailed: Windows PowerShell bootstrap is missing. Run Check-AudioFileForPhone.ps1 in an allowed PowerShell host.
exit /b 1
