@echo off
setlocal EnableExtensions

set "BN_PUSHED=0"
pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not enter the launcher directory: "%~dp0"
    set "BN_EXIT=2"
    goto :finish
)
set "BN_PUSHED=1"
set "BN_ROOT=%CD%"
set "PYTHONUTF8=1"
set "PYTHONUNBUFFERED=1"
set "PYTHONDONTWRITEBYTECODE=1"

if not exist "%BN_ROOT%\scripts\bn.py" (
    echo [ERROR] scripts\bn.py was not found in "%BN_ROOT%".
    set "BN_EXIT=2"
    goto :finish
)

set "BN_PYTHON=%BN_ROOT%\.venv\python.exe"
if not exist "%BN_PYTHON%" (
    echo [ERROR] The repo-local Python runtime was not found: "%BN_PYTHON%"
    echo Run setup-repo.cmd first.
    set "BN_EXIT=2"
    goto :finish
)

echo Starting Bonsai REPL with repo-local Python...
"%BN_PYTHON%" "%BN_ROOT%\scripts\bn.py" %*
set "BN_EXIT=%ERRORLEVEL%"

:finish
if not defined BN_EXIT set "BN_EXIT=1"
if not "%BN_NO_PAUSE%"=="1" if "%BN_PAUSE%"=="1" pause
if not "%BN_NO_PAUSE%"=="1" if not "%BN_EXIT%"=="0" if not defined BN_PAUSE pause
if "%BN_PUSHED%"=="1" popd
exit /b %BN_EXIT%
