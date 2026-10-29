@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "AFP_ACCEPTANCE_HOST=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "AFP_ACCEPTANCE_HOST=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
set "AFP_ACCEPTANCE_RUNNER=%~dp0Run-Windows-Acceptance.ps1"
if not exist "%AFP_ACCEPTANCE_HOST%" goto missing_host
if not exist "%AFP_ACCEPTANCE_RUNNER%" goto missing_runner
if not exist "%~dp0Acceptance.Common.ps1" goto missing_runner
if not exist "%~dp0Acceptance.Physical.ps1" goto missing_runner
if not exist "%~dp0Export-AcceptanceReport.ps1" goto missing_runner
if not exist "%~dp0kit-manifest.json" goto missing_runner
"%AFP_ACCEPTANCE_HOST%" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%AFP_ACCEPTANCE_RUNNER%"
set "AFP_ACCEPTANCE_EXIT=%ERRORLEVEL%"
echo.
echo Acceptance runner finished with exit code %AFP_ACCEPTANCE_EXIT%.
pause
exit /b %AFP_ACCEPTANCE_EXIT%

:missing_host
echo Windows PowerShell is unavailable. Acceptance could not start.
echo Keep the kit and report this message; do not change system settings.
pause
exit /b 1

:missing_runner
echo The acceptance kit is incomplete. Extract the complete Acceptance-Kit.zip again.
pause
exit /b 1
