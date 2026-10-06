@echo off
setlocal EnableExtensions

set "BN_SETUP_ROOT=%~dp0"
if not exist "%BN_SETUP_ROOT%scripts\setup-repo.ps1" (
    echo [ERROR] Setup script was not found: "%BN_SETUP_ROOT%scripts\setup-repo.ps1"
    exit /b 2
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    exit /b 9009
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BN_SETUP_ROOT%scripts\setup-repo.ps1" %*
exit /b %ERRORLEVEL%
