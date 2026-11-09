@echo off
rem Double-click launcher: runs Install-GenericAudioController.ps1 with Windows PowerShell 5.1
rem (the script asks for administrator rights by itself).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-GenericAudioController.ps1"
