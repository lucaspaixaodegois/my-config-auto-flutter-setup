@echo off
title Flutter Auto Setup
net session >nul 2>&1
if %errorLevel% == 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
) else (
    echo Solicitando privilegios de administrador...
    powershell -Command "Start-Process -FilePath '%0' -Verb RunAs"
)
