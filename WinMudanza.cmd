@echo off
rem WinMudanza - lanzador para doble clic.
rem Pide permisos de Administrador y ejecuta WinMudanza.ps1 sin cambiar la directiva de
rem ejecucion de PowerShell (sirve en un Windows recien instalado).
rem Los parametros se pasan tal cual, por ejemplo:  WinMudanza.cmd -Accion Aplicar -WhatIf

net session >nul 2>&1
if %errorlevel% neq 0 (
    if "%~1"=="" (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinMudanza.ps1" %*
echo.
pause
