@echo off
REM Wrapper to invoke scripts with the bundled Python 3.12 (PyOlymp).
REM
REM Usage:
REM   py-olymp <args>             -> runs Python interactively
REM   py-olymp script.py <args>   -> runs the script
REM   py-olymp -m pip ...         -> runs pip with bundled Python
REM
REM Why: the system PATH may have a different Python (e.g. 3.14) that
REM doesn't have netmiko installed because our offline wheels are 3.12.
REM This wrapper ALWAYS uses the version we set up.

set PY=%USERPROFILE%\PyOlymp\Python312\python.exe
if not exist "%PY%" (
    echo [py-olymp] ERROR: bundled Python not found: %PY%
    echo [py-olymp] Run setup-windows-offline.ps1 first.
    exit /b 1
)
"%PY%" %*
