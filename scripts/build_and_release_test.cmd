@echo off
setlocal enabledelayedexpansion

REM Build from specific commit - FOR TESTING/DEVELOPMENT ONLY
REM This script is used to test the update mechanism by building from older commits
REM Usage: build_and_release_test.cmd [commit_hash] [prod|test]
REM If no commit hash provided, defaults to 1f394db
REM If second parameter is "prod" or "production", creates production-style release (no test markers)
REM NOTE: For production releases, use build_and_release.cmd instead

if "%~1"=="" (
    set TARGET_COMMIT=1f394db
    echo No commit specified, using default: %TARGET_COMMIT%
) else (
    set TARGET_COMMIT=%~1
)

REM Check for production mode
set PRODUCTION_MODE=0
if /i "%~2"=="prod" set PRODUCTION_MODE=1
if /i "%~2"=="production" set PRODUCTION_MODE=1

echo ========================================
echo Camera Calibrator - Build from Old Commit
echo ========================================
echo.
echo Building from commit: %TARGET_COMMIT%
if !PRODUCTION_MODE!==1 (
    echo Mode: PRODUCTION (no test markers)
) else (
    echo Mode: TEST (with test markers)
)
echo.

REM Step 1: Fetch and checkout specific commit
echo [1/7] Fetching and checking out commit %TARGET_COMMIT%...
REM Change to project root (parent of scripts folder)
cd /d "%~dp0\.."
if not exist "source" (
    echo Cloning upstream repository...
    git clone https://github.com/Orkules/camera_calibrator.git source
    if errorlevel 1 (
        echo ERROR: Failed to clone repository
        pause
        exit /b 1
    )
    cd source
    git checkout %TARGET_COMMIT%
    if errorlevel 1 (
        echo ERROR: Failed to checkout commit %TARGET_COMMIT%
        cd ..
        pause
        exit /b 1
    )
    cd ..
) else (
    cd source
    echo Fetching latest changes...
    git fetch origin
    if errorlevel 1 (
        echo ERROR: Failed to fetch from upstream
        cd ..
        pause
        exit /b 1
    )
    echo Checking out commit %TARGET_COMMIT%...
    git checkout %TARGET_COMMIT%
    if errorlevel 1 (
        echo ERROR: Failed to checkout commit %TARGET_COMMIT%
        cd ..
        pause
        exit /b 1
    )
    cd ..
)
echo [OK] Checked out commit %TARGET_COMMIT%
echo.

REM Step 2: Copy project files into source and merge requirements
echo [2/7] Copying project files into source...
REM Ensure we're in project root
cd /d "%~dp0\.."

REM Copy project files
copy /Y "project\build_windows.cmd" "source\" >nul
copy /Y "project\pyinstaller_entry.py" "source\" >nul
copy /Y "project\update_checker.py" "source\" >nul
copy /Y "project\update_dialog.py" "source\" >nul
copy /Y "project\update_handler.py" "source\" >nul

REM Merge requirements: append our additions to upstream requirements.txt
echo Merging requirements...
type "source\requirements.txt" > "source\requirements_merged.txt"
echo. >> "source\requirements_merged.txt"
type "project\requirements_add.txt" >> "source\requirements_merged.txt"
move /Y "source\requirements_merged.txt" "source\requirements.txt" >nul

echo [OK] Project files copied and requirements merged
echo.

REM Step 3: Update version with commit hash
echo [3/7] Updating version...
REM Ensure we're in project root
cd /d "%~dp0\.."
cd source

REM Get commit hash (should be %TARGET_COMMIT% or full hash)
for /f "tokens=*" %%i in ('git rev-parse --short HEAD') do set COMMIT_HASH=%%i
for /f "tokens=*" %%i in ('git rev-parse HEAD') do set COMMIT_FULL=%%i

REM Read current version from project root version.txt (if exists), otherwise use default
set CURRENT_VERSION=1.0.0
if exist "..\version.txt" (
    for /f "tokens=*" %%i in (..\version.txt) do set CURRENT_VERSION=%%i
)

REM Remove commit hash if present (format: 1.0.0-abc1234 -> 1.0.0)
for /f "tokens=1 delims=-" %%i in ("%CURRENT_VERSION%") do set VERSION_BASE=%%i

REM Increment patch version using Python helper
for /f "tokens=*" %%i in ('python "%~dp0increment_version.py" "%VERSION_BASE%"') do set NEW_VERSION_BASE=%%i

set NEW_VERSION=!NEW_VERSION_BASE!-!COMMIT_HASH!

REM Update version.txt in project root (for tracking) and source (for build)
echo !NEW_VERSION! > ..\version.txt
echo !NEW_VERSION! > version.txt
echo [OK] Version updated: !NEW_VERSION!
cd ..
echo.

REM Step 4: Build executable
echo [4/7] Building executable...
REM Ensure we're in project root
cd /d "%~dp0\.."
cd source
call build_windows.cmd
if errorlevel 1 (
    echo ERROR: Build failed!
    cd ..
    pause
    exit /b 1
)
if not exist "dist\CameraCalibrator\CameraCalibrator.exe" (
    echo ERROR: Build failed - executable not found!
    cd ..
    pause
    exit /b 1
)
echo [OK] Build successful
cd ..
echo.

REM Step 5: Package for release
echo [5/7] Packaging release...
REM Ensure we're in project root
cd /d "%~dp0\.."
REM Use temporary directory in scripts folder, not root
set RELEASE_DIR=scripts\release_temp
if exist "%RELEASE_DIR%" (
    echo Cleaning previous release temp...
    rmdir /s /q "%RELEASE_DIR%"
)
mkdir "%RELEASE_DIR%"

REM Get commit date (parse "Date:" line to avoid percent-format issues)
cd source
for /f "tokens=1* delims=:" %%i in ('git log -1 --date=iso HEAD ^| findstr /B "Date"') do set "COMMIT_DATE=%%j"
set "COMMIT_DATE=!COMMIT_DATE:~1!"
if "!COMMIT_DATE!"=="" set "COMMIT_DATE=Unknown"
cd ..

REM Use version from earlier step
set RELEASE_TAG=v!NEW_VERSION!
if !PRODUCTION_MODE!==1 (
    set RELEASE_TITLE=Version !NEW_VERSION_BASE! (!COMMIT_HASH!)
) else (
    set RELEASE_TITLE=Version !NEW_VERSION_BASE! (!COMMIT_HASH!) - Test Build
)

echo Version: !NEW_VERSION!
echo Release tag: !RELEASE_TAG!
echo Commit hash: !COMMIT_HASH!
echo Full commit: !COMMIT_FULL!

REM Copy built files
echo Copying built files...
xcopy /E /I /Y "source\dist\CameraCalibrator\*" "%RELEASE_DIR%\CameraCalibrator\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy built files
    pause
    exit /b 1
)

REM Create version info
echo Creating version info...
echo Version: !NEW_VERSION! > "%RELEASE_DIR%\version_info.txt"
echo Version Base: !NEW_VERSION_BASE! >> "%RELEASE_DIR%\version_info.txt"
echo Source Commit: !COMMIT_FULL! >> "%RELEASE_DIR%\version_info.txt"
echo Short Hash: !COMMIT_HASH! >> "%RELEASE_DIR%\version_info.txt"
echo Build Date: %DATE% %TIME% >> "%RELEASE_DIR%\version_info.txt"
echo Commit Date: !COMMIT_DATE! >> "%RELEASE_DIR%\version_info.txt"
echo Source Repository: https://github.com/Orkules/camera_calibrator >> "%RELEASE_DIR%\version_info.txt"
if !PRODUCTION_MODE!==0 (
    echo NOTE: This is a test build from old commit >> "%RELEASE_DIR%\version_info.txt"
)

REM Create release notes file
echo Creating release notes...
if !PRODUCTION_MODE!==1 (
    REM Production-style release notes (same as build_and_release.cmd)
    echo Automated build from upstream commit !COMMIT_FULL! > "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Build Date: %DATE% %TIME% >> "%RELEASE_DIR%\release_notes.txt"
    echo Commit Date: !COMMIT_DATE! >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Source Repository: https://github.com/Orkules/camera_calibrator >> "%RELEASE_DIR%\release_notes.txt"
    echo Source Commit: !COMMIT_FULL! >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Installation: >> "%RELEASE_DIR%\release_notes.txt"
    echo 1. Download CameraCalibrator.zip >> "%RELEASE_DIR%\release_notes.txt"
    echo 2. Extract to desired location >> "%RELEASE_DIR%\release_notes.txt"
    echo 3. Run CameraCalibrator.exe >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Update Instructions: >> "%RELEASE_DIR%\release_notes.txt"
    echo - Backup your _internal/config.yaml and _internal/calibration_files/ if you've made custom changes >> "%RELEASE_DIR%\release_notes.txt"
    echo - Replace the entire CameraCalibrator folder with the new version >> "%RELEASE_DIR%\release_notes.txt"
    echo - Restore your backed-up config files >> "%RELEASE_DIR%\release_notes.txt"
) else (
    REM Test build release notes
    echo Test build from old commit %TARGET_COMMIT% > "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Build Date: %DATE% %TIME% >> "%RELEASE_DIR%\release_notes.txt"
    echo Commit Date: !COMMIT_DATE! >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Source Repository: https://github.com/Orkules/camera_calibrator >> "%RELEASE_DIR%\release_notes.txt"
    echo Source Commit: !COMMIT_FULL! >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo NOTE: This is a test build for testing the auto-update mechanism. >> "%RELEASE_DIR%\release_notes.txt"
    echo. >> "%RELEASE_DIR%\release_notes.txt"
    echo Installation: >> "%RELEASE_DIR%\release_notes.txt"
    echo 1. Download CameraCalibrator.zip >> "%RELEASE_DIR%\release_notes.txt"
    echo 2. Extract to desired location >> "%RELEASE_DIR%\release_notes.txt"
    echo 3. Run CameraCalibrator.exe >> "%RELEASE_DIR%\release_notes.txt"
)

REM Create zip in project root (this is the only file that should be in root)
echo Creating release package...
cd "%RELEASE_DIR%"
REM Create ZIP in project root
set ZIP_NAME=..\..\CameraCalibrator-!NEW_VERSION!.zip
if exist "%ZIP_NAME%" (
    echo Removing existing zip file...
    del /F /Q "%ZIP_NAME%"
)
powershell -Command "Compress-Archive -Path * -DestinationPath '%ZIP_NAME%' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create zip file
    cd ..\..
    pause
    exit /b 1
)
cd ..\..
echo [OK] Package created: CameraCalibrator-!NEW_VERSION!.zip
echo.

REM Step 6: Check for existing release
echo [6/7] Checking for existing release...
gh release view !RELEASE_TAG! --repo aiigoradam/camera-calibrator >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo WARNING: Release !RELEASE_TAG! already exists!
    echo Deleting existing release and tag...
    gh release delete !RELEASE_TAG! --repo aiigoradam/camera-calibrator --yes
    if errorlevel 1 (
        echo ERROR: Failed to delete existing release
        pause
        exit /b 1
    )
    git push origin --delete !RELEASE_TAG! >nul 2>&1
    if errorlevel 1 (
        echo WARNING: Tag !RELEASE_TAG! may not exist remotely, continuing...
    )
    echo [OK] Existing release and tag deleted
) else (
    echo [OK] No existing release found
)
echo.

REM Step 7: Create GitHub release
echo [7/7] Creating GitHub release...
echo.
echo Release details:
echo   Tag: !RELEASE_TAG!
echo   Title: !RELEASE_TITLE!
echo   Version: !NEW_VERSION!
echo   Files: CameraCalibrator-!NEW_VERSION!.zip, version_info.txt
echo   Repository: aiigoradam/camera-calibrator
echo.

gh release create !RELEASE_TAG! ^
    --title "!RELEASE_TITLE!" ^
    --notes-file "%RELEASE_DIR%\release_notes.txt" ^
    CameraCalibrator-!NEW_VERSION!.zip ^
    "%RELEASE_DIR%\version_info.txt" ^
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
    echo Next steps:
    echo   1. Go to the release URL above
    echo   2. Download the zip file
    echo   3. Extract and test the application
    echo   4. Then we'll build from latest commit to test update
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
    pause
    exit /b 1
)

REM Cleanup - remove temporary files
echo.
echo Cleaning up temporary files...
REM Ensure we're in project root
cd /d "%~dp0\.."
if exist "%RELEASE_DIR%" rmdir /s /q "%RELEASE_DIR%"

REM Reset source directory to pristine upstream state
REM This discards uncommitted changes but keeps the checked-out commit
echo Resetting source directory to pristine upstream state...
cd source
REM Reset to current HEAD (keeps the commit we checked out, discards uncommitted changes)
git reset --hard HEAD >nul 2>&1
REM Remove untracked files (build artifacts, our copied files, etc.)
git clean -fd >nul 2>&1
cd ..
echo [OK] Source directory reset to pristine upstream state (checked-out commit preserved)
echo [OK] Cleanup complete

echo.
echo ========================================
echo Build from old commit complete!
echo ========================================
echo.
echo Files created:
echo   - CameraCalibrator-!NEW_VERSION!.zip (in project root)
echo   - version.txt (updated in project root)
echo.
pause


