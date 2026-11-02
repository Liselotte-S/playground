@echo off
rem Windows setup launcher (auto-elevates to administrator)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Windows.ps1" %*
