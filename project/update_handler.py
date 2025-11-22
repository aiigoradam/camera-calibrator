#!/usr/bin/env python3
"""
Update handler that orchestrates the update process.
Handles config backup/restore and update installation.
"""

import sys
import os
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
import requests


def get_app_directory():
    """Get the application directory (where exe is located)."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    else:
        return Path(__file__).parent


def get_internal_directory():
    """Get the _internal directory path."""
    app_dir = get_app_directory()
    return app_dir / "_internal"


def backup_config_files():
    """
    Backup user-editable configuration files.
    Returns path to backup directory, or None if failed.
    """
    internal_dir = get_internal_directory()
    if not internal_dir.exists():
        print("Warning: _internal directory not found")
        return None

    backup_dir = Path(tempfile.gettempdir()) / "CameraCalibrator_backup"
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    files_to_backup = [
        ("config.yaml", "config.yaml"),
        ("calibration_files", "calibration_files"),
    ]
    
    backed_up = []
    for source_name, dest_name in files_to_backup:
        source_path = internal_dir / source_name
        dest_path = backup_dir / dest_name
        
        if source_path.exists():
            try:
                if source_path.is_file():
                    shutil.copy2(source_path, dest_path)
                elif source_path.is_dir():
                    if dest_path.exists():
                        shutil.rmtree(dest_path)
                    shutil.copytree(source_path, dest_path)
                backed_up.append(source_name)
                print(f"Backed up: {source_name}")
            except OSError as e:
                print(f"Error backing up {source_name}: {e}")
                return None
    
    if backed_up:
        print(f"Backup created at: {backup_dir}")
        return backup_dir
    else:
        print("No files to backup")
        return None


def restore_config_files(backup_dir):
    """
    Restore configuration files from backup.
    """
    if not backup_dir or not Path(backup_dir).exists():
        print("No backup directory to restore from")
        return False
    
    internal_dir = get_internal_directory()
    if not internal_dir.exists():
        print("Error: _internal directory not found for restore")
        return False
    
    backup_path = Path(backup_dir)
    files_to_restore = [
        ("config.yaml", "config.yaml"),
        ("calibration_files", "calibration_files"),
    ]
    
    restored = []
    for backup_name, dest_name in files_to_restore:
        backup_file = backup_path / backup_name
        dest_path = internal_dir / dest_name
        
        if backup_file.exists():
            try:
                if backup_file.is_file():
                    shutil.copy2(backup_file, dest_path)
                elif backup_file.is_dir():
                    if dest_path.exists():
                        shutil.rmtree(dest_path)
                    shutil.copytree(backup_file, dest_path)
                restored.append(dest_name)
                print(f"Restored: {dest_name}")
            except OSError as e:
                print(f"Error restoring {dest_name}: {e}")
                return False
    
    if restored:
        print(f"Successfully restored {len(restored)} file(s)")
        return True
    else:
        print("No files restored")
        return False


def download_update(download_url, progress_callback=None):
    """
    Download update zip file.
    Returns path to downloaded file.
    """
    try:
        response = requests.get(download_url, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get("content-length", 0))

        temp_dir = Path(tempfile.gettempdir())
        temp_file = temp_dir / f"CameraCalibrator_update_{os.getpid()}.zip"
        
        downloaded = 0
        with open(temp_file, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback and total_size > 0:
                        progress = (downloaded / total_size) * 100
                        progress_callback(progress)
        
        print(f"Downloaded update to: {temp_file}")
        return str(temp_file)
    
    except (requests.exceptions.RequestException, OSError) as e:
        print(f"Download failed: {e}")
        raise


def extract_update(zip_path, extract_to):
    """
    Extract update zip to specified directory.
    """
    extract_path = Path(extract_to)
    extract_path.mkdir(parents=True, exist_ok=True)
    
    try:
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(extract_path)
        print(f"Extracted update to: {extract_path}")
        return True
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError) as e:
        print(f"Extraction failed: {e}")
        return False


def apply_update(downloaded_zip_path, backup_dir=None):
    """
    Apply update by replacing current executable and _internal folder.
    Creates a batch script to handle the replacement after app closes.
    """
    if not getattr(sys, "frozen", False):
        raise RuntimeError("Updates can only be applied to frozen executables")
    
    app_dir = get_app_directory()
    exe_path = app_dir / "CameraCalibrator.exe"

    temp_extract = Path(tempfile.gettempdir()) / f"CameraCalibrator_update_extract_{os.getpid()}"
    if not extract_update(downloaded_zip_path, temp_extract):
        raise RuntimeError("Failed to extract update")

    extracted_camera_dir = None
    for item in temp_extract.iterdir():
        if item.is_dir() and item.name == "CameraCalibrator":
            extracted_camera_dir = item
            break
    
    if not extracted_camera_dir:
        raise FileNotFoundError("CameraCalibrator folder not found in update package")

    updater_script = app_dir / "apply_update.bat"

    new_exe_str = str(extracted_camera_dir / "CameraCalibrator.exe")
    new_internal_str = str(extracted_camera_dir / "_internal")
    old_exe_str = str(exe_path)
    old_internal_str = str(app_dir / "_internal")
    app_dir_str = str(app_dir)
    temp_extract_str = str(temp_extract)
    downloaded_zip_str = str(downloaded_zip_path)

    script_content = r"""@echo off
REM Camera Calibrator Update Script
REM This script will replace the application files after it closes

echo Waiting for application to close...
timeout /t 3 /nobreak >nul

REM Backup old files
if exist "{old_exe}" (
    move /Y "{old_exe}" "{old_exe}.old" >nul 2>&1
)
if exist "{old_internal}" (
    move /Y "{old_internal}" "{old_internal}.old" >nul 2>&1
)

REM Copy new files
echo Installing update...
copy /Y "{new_exe}" "{app_dir}\CameraCalibrator.exe" >nul
if exist "{old_internal}" rmdir /S /Q "{old_internal}" >nul 2>&1
mkdir "{app_dir}\_internal" >nul 2>&1
xcopy /E /Y "{new_internal}\*" "{app_dir}\_internal\" >nul
""".format(
        old_exe=old_exe_str,
        old_internal=old_internal_str,
        new_exe=new_exe_str,
        new_internal=new_internal_str,
        app_dir=app_dir_str,
    )
    
    if backup_dir:
        backup_path_str = str(Path(backup_dir))
        script_content += r"""
REM Restore config files if backup exists
if exist "{backup_path}\config.yaml" (
    copy /Y "{backup_path}\config.yaml" "{old_internal}\config.yaml" >nul 2>&1
    echo Restored config.yaml
)
if exist "{backup_path}\calibration_files" (
    xcopy /E /I /Y "{backup_path}\calibration_files" "{old_internal}\calibration_files\" >nul 2>&1
    echo Restored calibration_files
)
""".format(
            backup_path=backup_path_str, old_internal=old_internal_str
        )
    
    script_content += r"""
REM Launch updated application
echo Starting updated application...
if exist "{app_dir}\CameraCalibrator.exe" (
    start "" "{app_dir}\CameraCalibrator.exe"
    timeout /t 2 /nobreak >nul
) else (
    echo ERROR: CameraCalibrator.exe not found after update!
    pause
)

REM Clean up
del /F /Q "{old_exe}.old" >nul 2>&1
rmdir /S /Q "{old_internal}.old" >nul 2>&1
rmdir /S /Q "{temp_extract}" >nul 2>&1
del /F /Q "{downloaded_zip}" >nul 2>&1
del /F /Q "%~f0" >nul 2>&1
""".format(
        old_exe=old_exe_str,
        old_internal=old_internal_str,
        temp_extract=temp_extract_str,
        downloaded_zip=downloaded_zip_str,
        app_dir=app_dir_str,
    )
    
    updater_script.write_text(script_content)

    subprocess.Popen(
        [str(updater_script)], shell=True, creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == "win32" else 0
    )

    print("Update script created. Application will restart after closing.")
    return True
