@echo off
title FastUpTV - restore
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\restore.ps1" %*
echo.
pause
