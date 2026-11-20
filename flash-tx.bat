@echo off
rem Builds the transmitter firmware and copies it to the XIAO nRF52840 UF2 drive.
if not exist "%~dp0.venv\Scripts\esphome.exe" call "%~dp0setup.bat" || (pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash-tx.ps1"
pause
