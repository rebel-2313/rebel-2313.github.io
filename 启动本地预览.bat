@echo off
chcp 65001 >nul
title Personal Site - Local Preview
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
echo.
pause
