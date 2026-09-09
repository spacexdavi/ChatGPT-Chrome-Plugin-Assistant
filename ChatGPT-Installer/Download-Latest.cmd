@echo off
setlocal
title ChatGPT Extension - Download Latest
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
set "result=%errorlevel%"
echo.
pause
exit /b %result%
