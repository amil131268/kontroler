@echo off
setlocal
cd /d "%~dp0"
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
  echo Nie znaleziono Windows PowerShell. Program wymaga Windows 10 lub 11.
  pause
  exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Kontroler.ps1"
if errorlevel 1 (
  echo Nie udalo sie uruchomic Kontrolera. Sprawdz komunikat powyzej.
  pause
)
