@echo off
setlocal
rem ---------------------------------------------------------------------------
rem Self-contained release APK build for the Flutter todo app.
rem Sets the Android / Java toolchain env so a plain double-click works.
rem NOTE: requires the pre-downloaded Gradle distribution at
rem       D:\gradle-9.5.0-all.zip  (referenced by android/gradle/wrapper/
rem       gradle-wrapper.properties). Do NOT delete that file.
rem ---------------------------------------------------------------------------
set JAVA_HOME=D:\Java\jdk-17.0.21.0.2+1
set ANDROID_HOME=D:\Android\Sdk
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;D:\flutter\bin;%PATH%

cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter SDK not found. Install Flutter to D:\flutter or add it to PATH.
  pause
  exit /b 1
)
echo Building release APK ...
call flutter build apk --release
if errorlevel 1 (
  echo [ERROR] Build failed. Read the messages above.
  pause
  exit /b 1
)
echo.
echo APK  : build\app\outputs\flutter-apk\app-release.apk
if exist "build\app\outputs\flutter-apk" explorer "%~dp0build\app\outputs\flutter-apk"
pause
