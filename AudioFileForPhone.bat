@echo off
setlocal DisableDelayedExpansion

REM Exactly one folder; transport the spelling once without evaluating it.
set "AUDIOFILEFORPHONE_INPUT=%~1"
set "AFP_LAUNCHER=%~dp0AudioFileForPhone.Launcher.ps1"
set "AFP_BOOTSTRAP=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "AFP_BOOTSTRAP=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%AFP_LAUNCHER%" goto missing_launcher
if not exist "%AFP_BOOTSTRAP%" goto missing_host
if "%~1"=="" goto invalid_arguments
if not "%~2"=="" goto invalid_arguments
REM A quoted empty second argument is still an extra argument.
REM Inspect its raw spelling only after the dequoted value was proved empty.
if not "%2"=="" goto invalid_arguments

"%AFP_BOOTSTRAP%" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%AFP_LAUNCHER%"
set "CHILD_EXIT=%ERRORLEVEL%"
exit /b %CHILD_EXIT%

:invalid_arguments
"%AFP_BOOTSTRAP%" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%AFP_LAUNCHER%" -ShowUsage
exit /b 1

:missing_launcher
echo Required AudioFileForPhone.Launcher.ps1 is missing. Restore the complete application package.
echo [DIAGNOSTIC] stage=Bootstrap; code=HelperMissing.
REM Fixed reporting/wait command; paths travel through environment, never evaluation.
if exist "%AFP_BOOTSTRAP%" "%AFP_BOOTSTRAP%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command "try { $dir = [IO.Path]::GetDirectoryName($env:AFP_LAUNCHER); $diag = [IO.Path]::Combine($dir, 'AudioFileForPhone.Diagnostics.ps1'); if (Test-Path -LiteralPath $diag -PathType Leaf) { . $diag; $r = New-AudioDiagnosticRecord -ScriptDirectory $dir -Stage Bootstrap -Code HelperMissing -Message 'Required AudioFileForPhone.Launcher.ps1 is missing. Restore the complete application package.'; $null = Write-AudioStartupFailure -Record $r } } catch { Write-Warning 'Startup diagnostics unavailable; original failure above is unchanged.' }; try { if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) { Write-Host 'Press any key to close.'; $null = [Console]::ReadKey($true) } } catch { }"
exit /b 1

:missing_host
echo Windows PowerShell bootstrap is missing. Run AudioFileForPhone.ps1 directly in an allowed x64 STA host.
echo [DIAGNOSTIC] stage=Bootstrap; code=HostStartFailed. Console only: the bootstrap host could not start a logger.
exit /b 1
