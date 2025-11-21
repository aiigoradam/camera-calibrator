@echo off
setlocal

if not exist venv (
    python -m venv venv
)

call venv\Scripts\activate.bat

python -m pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

REM Clean previous build artifacts
if exist dist\CameraCalibrator (
    echo Cleaning previous build...
    rmdir /s /q dist\CameraCalibrator
)
if exist build (
    rmdir /s /q build
)

pyinstaller --noconfirm --clean ^
  --name "CameraCalibrator" ^
  --noupx ^
  --console ^
  --hiddenimport app ^
  --hiddenimport terminal_manager ^
  --hiddenimport stream_processor ^
  --hiddenimport com_port_scanner ^
  --hiddenimport update_checker ^
  --hiddenimport update_dialog ^
  --hiddenimport update_handler ^
  --hiddenimport tkinter ^
  --hiddenimport tkinter.ttk ^
  --hiddenimport tkinter.scrolledtext ^
  --hiddenimport tkinter.messagebox ^
  --add-data "templates;templates" ^
  --add-data "config.yaml;." ^
  --add-data "calibration_files;calibration_files" ^
  --add-data "luminar_eth_operation.txt;." ^
  --add-data "version.txt;." ^
  pyinstaller_entry.py

echo.
echo PyInstaller build complete. Check the dist\CameraCalibrator folder.
endlocal