@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Camera Calibrator - Build and Release
echo ========================================
echo.

REM Step 1: Fetch latest from upstream
echo [1/6] Fetching latest from upstream...
cd /d "%~dp0\.."
if not exist "source" (
    echo Cloning upstream repository...
    git clone https://github.com/Orkules/camera_calibrator.git source
    if errorlevel 1 (
        echo ERROR: Failed to clone repository
        pause
        exit /b 1
    )
) else (
    cd source
    echo Pulling latest changes...
    git fetch origin
    if errorlevel 1 (
        echo ERROR: Failed to fetch from upstream
        cd ..
        pause
        exit /b 1
    )
    git pull origin main
    if errorlevel 1 (
        echo ERROR: Failed to pull from upstream
        cd ..
        pause
        exit /b 1
    )
    cd ..
)
echo [OK] Upstream code updated
echo.

REM Step 2: Copy project files into source and merge requirements
echo [2/6] Copying project files into source...
cd /d "%~dp0\.."
copy /Y "project\build_windows.cmd" "source\" >nul
copy /Y "project\pyinstaller_entry.py" "source\" >nul
copy /Y "project\update_checker.py" "source\" >nul
copy /Y "project\update_dialog.py" "source\" >nul
copy /Y "project\update_handler.py" "source\" >nul

echo Merging requirements...
type "source\requirements.txt" > "source\requirements_merged.txt"
echo. >> "source\requirements_merged.txt"
type "project\requirements_add.txt" >> "source\requirements_merged.txt"
move /Y "source\requirements_merged.txt" "source\requirements.txt" >nul

echo [OK] Project files copied and requirements merged
echo.

REM Step 3: Update version with commit hash
echo [3/6] Updating version...
cd /d "%~dp0\.."
cd source

for /f "tokens=*" %%i in ('git rev-parse --short HEAD') do set COMMIT_HASH=%%i
for /f "tokens=*" %%i in ('git rev-parse HEAD') do set COMMIT_FULL=%%i

set CURRENT_VERSION=1.0.0
if exist "..\version.txt" (
    for /f "tokens=*" %%i in (..\version.txt) do set CURRENT_VERSION=%%i
)

for /f "tokens=1 delims=-" %%i in ("%CURRENT_VERSION%") do set VERSION_BASE=%%i
set PREV_VERSION=!CURRENT_VERSION!

for /f "tokens=*" %%i in ('python "%~dp0increment_version.py" "%VERSION_BASE%"') do set NEW_VERSION_BASE=%%i

set NEW_VERSION=!NEW_VERSION_BASE!-!COMMIT_HASH!

echo !NEW_VERSION! > ..\version.txt
echo !NEW_VERSION! > version.txt
echo [OK] Version updated: !NEW_VERSION!
cd ..
echo.

REM Step 4: Build executable
echo [4/6] Building executable...
cd /d "%~dp0\.."
cd source
call build_windows.cmd
if errorlevel 1 (
    echo ERROR: Build failed!
    cd ..
    call :restore_version
    pause
    exit /b 1
)
if not exist "dist\CameraCalibrator\CameraCalibrator.exe" (
    echo ERROR: Build failed - executable not found!
    cd ..
    call :restore_version
    pause
    exit /b 1
)
echo [OK] Build successful
cd ..
echo.

REM Step 5: Package for release
echo [5/6] Packaging release...
cd /d "%~dp0\.."
set RELEASE_DIR=scripts\release_temp
if exist "%RELEASE_DIR%" (
    echo Cleaning previous release temp...
    rmdir /s /q "%RELEASE_DIR%"
)
mkdir "%RELEASE_DIR%"

cd source
for /f "tokens=1* delims=:" %%i in ('git log -1 --date=iso HEAD ^| findstr /B "Date"') do set "COMMIT_DATE=%%j"
set "COMMIT_DATE=!COMMIT_DATE:~1!"
if "!COMMIT_DATE!"=="" set "COMMIT_DATE=Unknown"

for /f "tokens=*" %%i in ('powershell -Command "git log -1 --format=%%s HEAD"') do set "COMMIT_MESSAGE=%%i"
if "!COMMIT_MESSAGE!"=="" set "COMMIT_MESSAGE=No commit message"

for /f "tokens=*" %%i in ('powershell -Command "git log -1 --format=%%an HEAD"') do set "COMMIT_AUTHOR=%%i"
if "!COMMIT_AUTHOR!"=="" set "COMMIT_AUTHOR=Unknown"

cd ..

set RELEASE_TAG=v!NEW_VERSION!
set RELEASE_TITLE=Version !NEW_VERSION_BASE! (!COMMIT_HASH!)

echo Version: !NEW_VERSION!
echo Release tag: !RELEASE_TAG!
echo Commit hash: !COMMIT_HASH!
echo Full commit: !COMMIT_FULL!

echo Copying built files...
xcopy /E /I /Y "source\dist\CameraCalibrator\*" "%RELEASE_DIR%\CameraCalibrator\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy built files
    call :restore_version
    pause
    exit /b 1
)

echo Creating release notes...
for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format \"yyyy-MM-dd HH:mm:ss zzz\""') do set "BUILD_DATE=%%i"
echo !COMMIT_MESSAGE! > "%RELEASE_DIR%\release_notes.txt"
echo. >> "%RELEASE_DIR%\release_notes.txt"
echo Author: !COMMIT_AUTHOR! >> "%RELEASE_DIR%\release_notes.txt"
echo Hash: !COMMIT_HASH! >> "%RELEASE_DIR%\release_notes.txt"
echo Commit Date: !COMMIT_DATE! >> "%RELEASE_DIR%\release_notes.txt"
echo Source Repo: https://github.com/Orkules/camera_calibrator >> "%RELEASE_DIR%\release_notes.txt"
echo. >> "%RELEASE_DIR%\release_notes.txt"
echo Build Date: !BUILD_DATE! >> "%RELEASE_DIR%\release_notes.txt"

echo Creating release package...
cd "%RELEASE_DIR%"
set ZIP_NAME=..\..\CameraCalibrator-!NEW_VERSION!.zip
if exist "%ZIP_NAME%" (
    echo Removing existing zip file...
    del /F /Q "%ZIP_NAME%"
)
echo Waiting for build artifacts to unlock...
timeout /t 3 /nobreak >nul
powershell -Command "Compress-Archive -Path * -DestinationPath '%ZIP_NAME%' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create zip file
    cd ..\..
    call :restore_version
    pause
    exit /b 1
)
cd ..\..
echo [OK] Package created: CameraCalibrator-!NEW_VERSION!.zip
echo.

REM Step 6: Create GitHub release
echo [6/6] Creating GitHub release...
echo.
echo Release details:
echo   Tag: !RELEASE_TAG!
echo   Title: !RELEASE_TITLE!
echo   Version: !NEW_VERSION!
echo   Files: CameraCalibrator-!NEW_VERSION!.zip
echo   Repository: aiigoradam/camera-calibrator
echo.

gh release create !RELEASE_TAG! ^
    --title "!RELEASE_TITLE!" ^
    --notes-file "%RELEASE_DIR%\release_notes.txt" ^
    CameraCalibrator-!NEW_VERSION!.zip ^
    --repo aiigoradam/camera-calibrator

if %ERRORLEVEL% == 0 (
    echo.
    echo ========================================
    echo [OK] Release created successfully!
    echo ========================================
    echo.
    echo Release URL:
    echo   https://github.com/aiigoradam/camera-calibrator/releases/tag/!RELEASE_TAG!
    echo.
    echo Apps will check this release for updates on next launch.
) else (
    echo.
    echo ========================================
    echo ERROR: Failed to create release
    echo ========================================
    echo.
    echo Possible issues:
    echo   1. Not authenticated with GitHub CLI
    echo      Run: gh auth login
    echo.
    echo   2. No write access to repository
    echo      Check repository permissions
    echo.
    echo   3. Network issues
    echo      Check internet connection
    echo.
    call :restore_version
    pause
    exit /b 1
)

echo.
echo Cleaning up temporary files...
cd /d "%~dp0\.."
if exist "%RELEASE_DIR%" rmdir /s /q "%RELEASE_DIR%"

echo Resetting source directory to pristine upstream state...
cd source
git reset --hard HEAD >nul 2>&1
git clean -fd >nul 2>&1
cd ..
echo [OK] Source directory reset to pristine upstream state
echo [OK] Cleanup complete

echo.
echo ========================================
echo Build and release complete!
echo ========================================
echo.
echo Files created:
echo   - CameraCalibrator-!NEW_VERSION!.zip (in project root)
echo   - version.txt (updated in project root)
echo.
pause

goto :eof

:restore_version
if not defined PREV_VERSION goto :eof
pushd "%~dp0\.."
echo !PREV_VERSION!>version.txt
if exist "source\version.txt" (
    echo !PREV_VERSION!>"source\version.txt"
)
popd
echo [INFO] Version reverted to !PREV_VERSION! due to failure.
goto :eof

