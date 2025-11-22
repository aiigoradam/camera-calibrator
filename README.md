# Camera Calibrator Build and Release System

This repository automates builds and releases for the Camera Calibrator application. It packages the upstream Flask application into a Windows executable with automatic updates.

## Overview

The build system fetches code from upstream, integrates the update system, builds a Windows executable with PyInstaller, and creates GitHub releases. The application checks for updates on startup and installs them automatically.

## Project Structure

```text
.
├── project/                        # Build integration files
│   ├── pyinstaller_entry.py   
│   ├── update_checker.py      
│   ├── update_dialog.py       
│   ├── update_handler.py      
│   ├── build_windows.cmd      
│   └── requirements_add.txt   
├── scripts/                        # Build orchestration scripts
│   ├── build_and_release.cmd  
│   ├── build_and_release_test.cmd  
│   └── increment_version.py   
├── source/                         # Upstream repository clone (gitignored)
├── version.txt          
└── README.md            
```

## Features

### Auto-Update System

The application checks GitHub releases on startup and prompts users when updates are available. When accepted:

- (Optionally) backs up configuration files
- Downloads and installs the update, then restarts.

### Versioning

Versions use the format `x.x.x-commithash` (e.g., `1.0.2-367331d`). Version numbers increment automatically on each release. Version comparison uses only the base version number.

## Prerequisites

- Python 3.x with pip
- Git
- GitHub CLI authenticated with repository access
- Windows

## Building a Release

Run `scripts/build_and_release.cmd` to create a release from the latest upstream commit. The script fetches code to `source/`, integrates updates, increments version, builds the executable, and creates a GitHub release.

## How It Works

### Build Process

1. **Fetch Upstream**: Clones or updates the `source/` directory from `Orkules/camera_calibrator`
2. **Integrate Updates**: Copies update system files from `project/` into `source/`
3. **Version Management**: Reads `version.txt`, increments patch version, appends commit hash
4. **Build**: Runs PyInstaller to create `CameraCalibrator.exe` with all dependencies
5. **Package**: Creates a ZIP file containing the executable and `_internal/` folder
6. **Release**: Uploads to GitHub as a release with release notes

### Update System

When users run the application:

1. **Check on Startup**: `pyinstaller_entry.py` checks GitHub for the latest release
2. **Version Comparison**: Compares current version (from `_internal/version.txt`) with latest release
3. **User Prompt**: If an update is available, shows a dialog with release notes
4. **Download & Install**: If accepted, downloads the update ZIP and applies it
5. **Restart**: Application automatically restarts with the new version

## Configuration

### Repository Settings

Update the repository information in `project/update_checker.py`:

```python
REPO_OWNER = "aiigoradam"
REPO_NAME = "camera-calibrator"
```

### Upstream Repository

Configured in the build scripts:

- Repository: `https://github.com/Orkules/camera_calibrator`
- Branch: `main`

## Release Notes Format

Release notes are automatically generated from commit information:

```text
[Commit Message]

Author: [Author Name]
Date: [Commit Date]
Hash: [Short Hash]

Source Repository: https://github.com/Orkules/camera_calibrator
Build Date: [Build Date/Time]
```
