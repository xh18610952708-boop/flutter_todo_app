@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter SDK not found in PATH. Run setup.bat first.
  pause
  exit /b 1
)
echo Connect an Android phone with USB debugging ON, or start an emulator.
echo (iOS needs macOS + Xcode.)
echo.
call flutter devices
echo.
call flutter run
pause
