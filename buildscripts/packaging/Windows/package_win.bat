@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "LOG=C:\DBStudio\package_win.log"
set "SOURCE="
set "SUCCESS=0"
> "%LOG%" echo === 鼓乐熊Studio Windows package ===
>> "%LOG%" echo START=%DATE% %TIME%

taskkill /f /im DBStudio5.exe >nul 2>&1

rem Always package the tree that contains this script, never a glob over the
rem desktop (a glob could pick a stale/older source folder).
set "SOURCE=%~dp0..\..\.."
for %%I in ("!SOURCE!") do set "SOURCE=%%~fI"

>> "%LOG%" echo SOURCE=!SOURCE!
robocopy "!SOURCE!" C:\DBStudio /E /XD "!SOURCE!\applebuild" "!SOURCE!\builds" "!SOURCE!\.git" "!SOURCE!\.github" /NFL /NDL /NJH /NJS /NC /NS /NP >> "%LOG%" 2>&1
set "ROBOCOPY_EXIT=!ERRORLEVEL!"
if !ROBOCOPY_EXIT! GEQ 8 (
  >> "%LOG%" echo RobocopyExit=!ROBOCOPY_EXIT!
  goto :fail
)
if exist C:\DBStudio\applebuild rmdir /s /q C:\DBStudio\applebuild
if exist C:\DBStudio\builds rmdir /s /q C:\DBStudio\builds

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
  >> "%LOG%" echo VcVarsExit=1
  goto :fail
)
set "PATH=C:\Qt\6.10.2\msvc2022_64\bin;C:\Mac\Home\.guyuexiong-build-tools\WiX314;%PATH%"

cd /d C:\DBStudio\build
if errorlevel 1 goto :fail
cmake . -U CPACK_WIX_PRODUCT_GUID -U CPACK_WIX_UPGRADE_GUID -DLIB_ARCH=x86_64 -DMUE_RUN_WINDEPLOYQT=ON -DMUE_WINDEPLOY_QML_DIR=C:/DBStudio/buildscripts/packaging/Windows/deploy-qml >> "%LOG%" 2>&1
if errorlevel 1 (
  >> "%LOG%" echo ConfigureExit=1
  goto :fail
)

ninja DBScore >> "%LOG%" 2>&1
set "BUILD_EXIT=%ERRORLEVEL%"
echo BuildExit=%BUILD_EXIT% >> "%LOG%"
if not "%BUILD_EXIT%"=="0" goto :fail

cmake --build . --target install >> "%LOG%" 2>&1
set "INSTALL_EXIT=%ERRORLEVEL%"
echo InstallExit=%INSTALL_EXIT% >> "%LOG%"
if not "%INSTALL_EXIT%"=="0" goto :fail

if not exist "C:\DBStudio\install\bin\Qt6Core5Compat.dll" (
  >> "%LOG%" echo MissingQt6Core5Compat
  goto :fail
)
if not exist "C:\DBStudio\install\bin\Qt6Core.dll" (
  >> "%LOG%" echo MissingQt6Core
  goto :fail
)
if not exist "C:\DBStudio\install\bin\platforms\qwindows.dll" (
  >> "%LOG%" echo MissingQWindowsPlugin
  goto :fail
)
if not exist "C:\DBStudio\install\qml\QtQuick\qmldir" (
  >> "%LOG%" echo MissingQtQuickQml
  goto :fail
)
if not exist "C:\DBStudio\install\qml\QtMultimedia\qmldir" (
  >> "%LOG%" echo MissingQtMultimediaQml
  goto :fail
)
if not exist "C:\DBStudio\install\bin\Qt6Multimedia.dll" (
  >> "%LOG%" echo MissingQt6Multimedia
  goto :fail
)
if not exist "C:\DBStudio\install\bin\multimedia\ffmpegmediaplugin.dll" (
  >> "%LOG%" echo MissingFfmpegMediaPlugin
  goto :fail
)
if not exist "C:\DBStudio\install\qml\Qt5Compat\GraphicalEffects\qmldir" (
  >> "%LOG%" echo MissingQt5CompatGraphicalEffectsQml
  goto :fail
)
if not exist "C:\DBStudio\install\locale\qt_zh_CN.qm" (
  >> "%LOG%" echo MissingChineseTranslations
  goto :fail
)

rem Translation sources are build inputs; the packaged app only needs compiled .qm catalogs.
for %%D in (C:\DBStudio\install\locale C:\DBStudio\install\share\locale) do (
  if exist "%%~D" del /s /q "%%~D\*.ts" >nul 2>&1
)

del /q C:\DBStudio\build\DBStudio-*.msi 2>nul
cpack -G WIX -C Release >> "%LOG%" 2>&1
set "PACKAGE_EXIT=%ERRORLEVEL%"
echo PackageExit=%PACKAGE_EXIT% >> "%LOG%"
if not "%PACKAGE_EXIT%"=="0" goto :fail

set "MSIFILE="
for %%F in (C:\DBStudio\build\DBStudio-*.msi) do set "MSIFILE=%%F"
if not defined MSIFILE (
  echo MSI_NOT_FOUND >> "%LOG%"
  goto :fail
)

set "VERSION="
set /p VERSION=<C:\DBStudio\release-version.txt
if not defined VERSION goto :fail

cscript //nologo C:\DBStudio\buildscripts\packaging\Windows\validate_windows_msi.vbs "!MSIFILE!" "DB Studio" "{11111111-1111-1111-1111-111111111111}" "!VERSION!" >> "%LOG%" 2>&1
if errorlevel 1 goto :fail

copy /y "!MSIFILE!" "C:\Mac\Home\Desktop\DB-Studio-Windows-!VERSION!.msi" >> "%LOG%" 2>&1
set "COPY_MSI_EXIT=!ERRORLEVEL!"
echo CopyMsiExit=!COPY_MSI_EXIT! >> "%LOG%"
if not "!COPY_MSI_EXIT!"=="0" goto :fail

copy /y "!MSIFILE!" "C:\Mac\Home\Desktop\DB Studio.msi" >> "%LOG%" 2>&1
set "COPY_PUBLIC_MSI_EXIT=!ERRORLEVEL!"
echo CopyPublicMsiExit=!COPY_PUBLIC_MSI_EXIT! >> "%LOG%"
if not "!COPY_PUBLIC_MSI_EXIT!"=="0" goto :fail

set "SUCCESS=1"
goto :finish

:fail
>> "%LOG%" echo RESULT=FAILED
goto :cleanup

:finish
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\DBStudio\buildscripts\packaging\Windows\cleanup_old_windows_versions.ps1" -Version "!VERSION!" >> "%LOG%" 2>&1
set "CLEANUP_EXIT=!ERRORLEVEL!"
echo LatestOnlyCleanupExit=!CLEANUP_EXIT! >> "%LOG%"
if not "!CLEANUP_EXIT!"=="0" (
  >> "%LOG%" echo RESULT=FAILED_CLEANUP
  set "SUCCESS=0"
)
if "!SUCCESS!"=="1" >> "%LOG%" echo RESULT=SUCCESS

:cleanup
echo END=%DATE% %TIME% >> "%LOG%"
copy /y "%LOG%" "C:\Mac\Home\dbstudio_windows_package.log" >nul 2>&1
if "!SUCCESS!"=="1" exit /b 0
exit /b 1
