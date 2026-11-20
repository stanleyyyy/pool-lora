@echo off
rem Starts ESPHome Device Builder (the dashboard) for this folder.
rem Open http://localhost:6052 in a browser. Close this window to stop it.
cd /d "%~dp0"
rem Force UTF-8 so YAML files with accents or degree signs are read correctly on Windows
set PYTHONUTF8=1
".venv\Scripts\esphome-device-builder.exe" --host 127.0.0.1 --port 6052 .
pause
