@echo off
setlocal
cd /d "%~dp0"
set "BK=%TEMP%\flutter_todo_backup"

echo ============================================
echo  Flutter Todo App - one click setup
echo ============================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter SDK not found in PATH.
  echo Install Flutter SDK first, then double-click this file again.
  echo https://docs.flutter.dev/get-started/install/windows
  pause
  exit /b 1
)

call flutter --version

if exist "android" goto shell_ready

echo.
echo [1/3] Backing up lib\ and config files ...
if exist "%BK%" rd /s /q "%BK%"
xcopy /E /I /Y "lib" "%BK%\lib" >nul
copy /Y "pubspec.yaml" "%BK%\pubspec.yaml" >nul
copy /Y "analysis_options.yaml" "%BK%\analysis_options.yaml" >nul
copy /Y ".gitignore" "%BK%\gitignore.bak" >nul

echo [2/3] Generating Android / iOS native shell ...
call flutter create --org com.ruitu --project-name flutter_todo_app --platforms=android,ios .
if errorlevel 1 (
  echo [ERROR] flutter create failed. Your source backup is at %BK%
  pause
  exit /b 1
)

echo Restoring source files ...
xcopy /E /I /Y "%BK%\lib" "lib" >nul
copy /Y "%BK%\pubspec.yaml" "pubspec.yaml" >nul
copy /Y "%BK%\analysis_options.yaml" "analysis_options.yaml" >nul
copy /Y "%BK%\gitignore.bak" ".gitignore" >nul
rem flutter create generates a template test that references MyApp; remove it
if exist "test\widget_test.dart" del /q "test\widget_test.dart"
goto deps

:shell_ready
echo.
echo [1/3] Native shell already exists, skip flutter create.
echo [2/3] Nothing to generate.

:deps
echo.
echo [3/3] Installing packages (flutter pub get) ...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed. Check network or pub mirror.
  pause
  exit /b 1
)

echo.
echo ============================================
echo  DONE.
echo  Debug run : flutter run
echo  Android   : flutter build apk --release
echo  iOS       : flutter build ipa --release  (macOS + Xcode only)
echo ============================================
pause
