@echo off
setlocal EnableExtensions

set "BON_PUSHED=0"
pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not enter the launcher directory: "%~dp0"
    set "BON_EXIT=2"
    goto :finish
)
set "BON_PUSHED=1"
set "BON_ROOT=%CD%"
set "PYTHONUTF8=1"
set "PYTHONUNBUFFERED=1"
set "PYTHONDONTWRITEBYTECODE=1"

if not exist "%BON_ROOT%\scripts\bon.py" (
    echo [ERROR] scripts\bon.py was not found in "%BON_ROOT%".
    set "BON_EXIT=2"
    goto :finish
)

set "BON_PYTHON=%BON_ROOT%\.venv\Scripts\python.exe"
if not exist "%BON_PYTHON%" (
    echo [ERROR] The repo-local Python runtime was not found: "%BON_PYTHON%"
    echo Run setup-repo.cmd first.
    set "BON_EXIT=2"
    goto :finish
)

echo Starting Bon with repo-local Python...
"%BON_PYTHON%" "%BON_ROOT%\scripts\bon.py" %*
set "BON_EXIT=%ERRORLEVEL%"

:finish
if not defined BON_EXIT set "BON_EXIT=1"
if not "%BON_NO_PAUSE%"=="1" if "%BON_PAUSE%"=="1" pause
if not "%BON_NO_PAUSE%"=="1" if not "%BON_EXIT%"=="0" if not defined BON_PAUSE pause
if "%BON_PUSHED%"=="1" popd
exit /b %BON_EXIT%
