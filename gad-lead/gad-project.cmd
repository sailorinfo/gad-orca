@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\gad-project.ps1" %*
exit /b %ERRORLEVEL%
