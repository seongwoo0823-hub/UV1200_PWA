@echo off
setlocal
rem UV1200 Web Control - local launcher / installer (no install needed, uses built-in Windows PowerShell)
title UV1200 Web Control (local server)
chcp 65001 >nul
set "UV_ROOT=%~dp0"
if not exist "%~dp0index.html" (
  echo [ERROR] index.html not found. Unzip the whole folder first, then run this file again.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $env:UV_ROOT 'tools\server.ps1'))"
if errorlevel 2 (
  pause
  goto :end
)
if errorlevel 1 (
  echo.
  echo [ERROR] Could not start the local server. PowerShell may be blocked on this PC.
  echo         Use GitHub Pages instead - see the install guide txt file.
  pause
)
:end
endlocal
