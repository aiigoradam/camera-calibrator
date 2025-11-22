#!/usr/bin/env python3
"""
PyInstaller entry point that bootstraps the upstream Flask app and
handles the self-update workflow before launching the UI.
"""

import os
import runpy
import sys
import traceback
from typing import Optional


def _import_update_modules():
    """
    Import update modules lazily so the main app can still launch if any
    dependency is missing. Returns a tuple with callables or None.

    Returns:
        tuple: (check_for_updates, UpdateDialog, download_update, apply_update, backup_config_files)
               or None if imports fail
    """
    try:
        from update_checker import check_for_updates
        from update_dialog import UpdateDialog
        from update_handler import download_update, apply_update, backup_config_files

        return check_for_updates, UpdateDialog, download_update, apply_update, backup_config_files
    except (ImportError, ModuleNotFoundError) as exc:
        # Module or dependency not found
        print(f"[Updater] Disabled (missing dependency): {exc}")
    except AttributeError as exc:
        # Module imported but missing expected attributes/functions
        print(f"[Updater] Disabled (module missing expected attributes): {exc}")
        traceback.print_exc()
    except SyntaxError as exc:
        # Module has syntax errors (shouldn't happen in production, but defensive)
        print(f"[Updater] Disabled (syntax error in module): {exc}")
        traceback.print_exc()

    return None


def _should_run_update_check() -> bool:
    """
    Determine if the update check should run.
    Prevents duplicates in Flask reloader processes and repeated checks.
    """
    # 1. Skip if Flask reloader child process (WERKZEUG_RUN_MAIN=true)
    if os.environ.get("WERKZEUG_RUN_MAIN", "").lower() == "true":
        return False

    # 2. Skip if update check already completed (persists across reloader processes)
    if os.environ.get("CAMERA_CALIBRATOR_UPDATE_CHECKED", "").lower() == "true":
        return False

    return True


def handle_updates():
    """
    Check GitHub for new releases and prompt the user before launching the app.
    """
    if not _should_run_update_check():
        return

    # Mark that update check has been done (persists across reloader processes)
    os.environ["CAMERA_CALIBRATOR_UPDATE_CHECKED"] = "true"

    try:
        imported = _import_update_modules()
        if not imported:
            return

        (check_for_updates, UpdateDialog, download_update, apply_update, backup_config_files) = imported

        update_info = check_for_updates()
        if not update_info or not update_info.get("update_available"):
            return

        dialog = UpdateDialog(update_info)
        result = dialog.show() or {}
        if result.get("choice") != "accept":
            # User skipped the update; continue launching the app
            return

        backup_dir: Optional[str] = None
        if result.get("backup_configs", True):
            backup_dir = backup_config_files()

        download_url = update_info.get("download_url")
        if not download_url:
            print("[Updater] No download asset found; skipping update")
            return

        print("[Updater] Downloading update...")
        download_path = download_update(download_url)
        if not download_path:
            print("[Updater] Download failed; launching current version")
            return

        print("[Updater] Applying update...")
        if apply_update(download_path, backup_dir=backup_dir):
            print("[Updater] Update scheduled. Application will restart after this instance exits.")
            sys.exit(0)

    except (RuntimeError, OSError, ImportError, FileNotFoundError, LookupError, ValueError) as exc:
        # Catch specific errors that might occur during update process
        # Includes: runtime, file I/O, import, file not found, lookup, and value errors
        print(f"[Updater] Error while handling updates: {exc}")
        traceback.print_exc()


def launch_app():
    """Launch the upstream Flask application exactly as `python app.py` would."""
    # Disable Flask reloader in PyInstaller build to prevent duplicate update checks
    os.environ["FLASK_ENV"] = "production"
    os.environ["FLASK_DEBUG"] = "0"

    try:
        runpy.run_module("app", run_name="__main__")
    except (ImportError, ModuleNotFoundError, SyntaxError) as exc:
        # Catch module loading errors specifically
        print(f"[Launcher] Fatal error while starting application: {exc}")
        traceback.print_exc()
        raise
    except Exception as exc:
        # Catch-all for unexpected runtime errors before re-raising
        print(f"[Launcher] Fatal error while starting application: {exc}")
        traceback.print_exc()
        raise


if __name__ == "__main__":
    handle_updates()
    launch_app()
