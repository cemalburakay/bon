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

if not exist "%BN_ROOT%\bn.py" (
    echo [ERROR] bn.py was not found in "%BN_ROOT%".
    set "BN_EXIT=2"
    goto :finish
)

set "BN_PYTHON="
set "BN_PYTHON_ARGS="
if exist "%BN_ROOT%\tools\runtime-python\python.exe" (
    "%BN_ROOT%\tools\runtime-python\python.exe" --version >nul 2>&1
    if not errorlevel 1 set "BN_PYTHON=%BN_ROOT%\tools\runtime-python\python.exe"
)
if not defined BN_PYTHON if exist "%BN_ROOT%\tools\python\python.exe" (
    "%BN_ROOT%\tools\python\python.exe" --version >nul 2>&1
    if not errorlevel 1 set "BN_PYTHON=%BN_ROOT%\tools\python\python.exe"
)
if not defined BN_PYTHON (
    for /f "delims=" %%P in ('where python 2^>nul') do (
        if not defined BN_PYTHON (
            "%%P" --version >nul 2>&1
            if not errorlevel 1 set "BN_PYTHON=%%P"
        )
    )
)
if not defined BN_PYTHON (
    for /f "delims=" %%P in ('where py 2^>nul') do (
        if not defined BN_PYTHON (
            "%%P" -3 --version >nul 2>&1
            if not errorlevel 1 (
                set "BN_PYTHON=%%P"
                set "BN_PYTHON_ARGS=-3"
            )
        )
    )
)
if not defined BN_PYTHON (
    echo [ERROR] Python 3 was not found. Install Python or add the portable interpreter under tools\python\.
    set "BN_EXIT=9009"
    goto :finish
)

echo Starting Bonsai REPL with %BN_PYTHON%...
"%BN_PYTHON%" %BN_PYTHON_ARGS% "%BN_ROOT%\bn.py" %*
set "BN_EXIT=%ERRORLEVEL%"

:finish
if not defined BN_EXIT set "BN_EXIT=1"
if not "%BN_NO_PAUSE%"=="1" if "%BN_PAUSE%"=="1" pause
if not "%BN_NO_PAUSE%"=="1" if not "%BN_EXIT%"=="0" if not defined BN_PAUSE pause
if "%BN_PUSHED%"=="1" popd
exit /b %BN_EXIT%
