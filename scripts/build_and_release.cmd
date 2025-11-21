@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Camera Calibrator - Build and Release
echo ========================================
echo.

REM Step 1: Fetch latest from upstream
echo [1/7] Fetching latest from upstream...
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

REM Get commit hash first
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
set RELEASE_TITLE=Version !NEW_VERSION_BASE! (!COMMIT_HASH!)

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

REM Create release notes file
echo Creating release notes...
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
    echo.
    echo WARNING: Release !RELEASE_TAG! already exists!
    echo.
    echo Options:
    echo   1. Delete existing release and create new one
    echo   2. Skip release creation (keep existing)
    echo   3. Cancel
    echo.
    set /p choice="Enter choice (1/2/3): "
    if "!choice!"=="1" (
        echo Deleting existing release...
        gh release delete !RELEASE_TAG! --repo aiigoradam/camera-calibrator --yes
        if errorlevel 1 (
            echo ERROR: Failed to delete existing release
            pause
            exit /b 1
        )
        echo [OK] Existing release deleted
    ) else if "!choice!"=="2" (
        echo Skipping release creation.
        pause
        exit /b 0
    ) else if "!choice!"=="3" (
        echo Cancelled.
        pause
        exit /b 0
    ) else (
        echo Skipping release creation.
        pause
        exit /b 0
    )
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
REM This discards uncommitted changes but keeps the latest upstream commit
echo Resetting source directory to pristine upstream state...
cd source
REM Reset to current HEAD (keeps the latest commit we pulled, discards uncommitted changes)
git reset --hard HEAD >nul 2>&1
REM Remove untracked files (build artifacts, our copied files, etc.)
git clean -fd >nul 2>&1
cd ..
echo [OK] Source directory reset to pristine upstream state (latest commit preserved)
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

