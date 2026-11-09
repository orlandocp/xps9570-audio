@echo off
rem Installs Dell's Realtek audio driver on the codec. Run after Install-GenericAudioController.bat. See Install-DellRealtekDriver.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-DellRealtekDriver.ps1"
