@echo off
rem One-time setup: creates .venv with ESPHome and Device Builder, and secrets.yaml.
rem Safe to run again; it only adds what is missing or out of date.
setlocal
cd /d "%~dp0"

set "PY="
where py >nul 2>&1 && set "PY=py -3"
if not defined PY where python >nul 2>&1 && set "PY=python"
if not defined PY (
    echo Python 3.11 or newer is required: https://www.python.org/downloads/
    exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
    echo Creating .venv ...
    %PY% -m venv .venv || exit /b 1
)

echo Installing ESPHome and Device Builder ...
".venv\Scripts\python.exe" -m pip install --quiet --upgrade pip || exit /b 1
".venv\Scripts\python.exe" -m pip install --quiet -r requirements.txt || exit /b 1

if not exist "secrets.yaml" (
    copy /y "secrets.example.yaml" "secrets.yaml" >nul
    echo Created secrets.yaml - edit it with your Wi-Fi and API values before flashing the receiver.
)

".venv\Scripts\esphome.exe" version
echo Setup done.
endlocal
