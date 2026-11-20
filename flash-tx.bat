@echo off
rem Builds the transmitter firmware and copies it to the XIAO nRF52840 UF2 drive.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash-tx.ps1"
pause
