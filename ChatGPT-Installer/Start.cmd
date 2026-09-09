@echo off
setlocal
title ChatGPT Extension Helper
if exist "%~dp0official.crx" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -CrxPath "%~dp0official.crx"
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
)
set "result=%errorlevel%"
echo.
pause
exit /b %result%
