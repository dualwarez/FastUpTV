@echo off
title FastUpTV - web UI
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js chahiye - https://nodejs.org se install karo
  pause
  exit /b 1
)
node web\server.js
pause
