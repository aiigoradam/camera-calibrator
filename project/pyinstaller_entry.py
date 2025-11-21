#!/usr/bin/env python3
"""
PyInstaller wrapper entry point.
"""

import runpy
import sys
import threading
import time
import webbrowser

# Import update modules (only when frozen)
UPDATE_ENABLED = False
if getattr(sys, "frozen", False):
    try:
        from update_checker import check_for_updates
        from update_dialog import UpdateDialog
        from update_handler import backup_config_files, download_update, apply_update
        UPDATE_ENABLED = True
    except ImportError as e:
        # Update system not available - continue without it
        print(f"Update system not available: {e}")
        UPDATE_ENABLED = False
    except Exception as e:
        # Any other error - continue without updates
        print(f"Error loading update system: {e}")
        UPDATE_ENABLED = False
else:
    UPDATE_ENABLED = False


def handle_updates():
    """Check and handle updates if running as frozen executable."""
    if not UPDATE_ENABLED:
        return False
    
    try:
        # Silent check for updates (with timeout)
        try:
            update_info = check_for_updates()
        except Exception as e:
            # If check fails, just continue
            print(f"Update check failed: {e}")
            return False
        
        if not update_info.get('update_available'):
            return False  # No update, continue normally
        
        # Show update dialog (with error handling)
        try:
            dialog = UpdateDialog(update_info)
            result = dialog.show()
        except Exception as e:
            print(f"Error showing update dialog: {e}")
            # If dialog fails, just continue without updating
            return False
        
        if result['choice'] == 'accept':
            try:
                # Backup configs if user requested
                backup_dir = None
                if result['backup_configs']:
                    print("Backing up configuration files...")
                    backup_dir = backup_config_files()
                    if backup_dir:
                        print(f"Configuration files backed up to: {backup_dir}")
                
                # Download update
                print("Downloading update...")
                downloaded_file = download_update(update_info['download_url'])
                
                # Apply update (will restart app)
                print("Applying update...")
                apply_update(downloaded_file, backup_dir)
                print("Update applied. Application will restart.")
                
                # Exit current instance (updater script will restart)
                sys.exit(0)
                
            except Exception as e:
                print(f"Update failed: {e}")
                import tkinter.messagebox as msgbox
                msgbox.showerror(
                    "Update Failed",
                    f"Failed to apply update:\n{str(e)}\n\nContinuing with current version."
                )
                return False
        
        # User rejected or update failed - continue with current version
        return False
    
    except Exception as e:
        print(f"Update check error: {e}")
        return False  # Continue with app launch on error


if __name__ == "__main__":
    # Check for updates if running as executable
    UPDATE_CHECK_DISABLED = False  # Updates enabled
    
    if getattr(sys, "frozen", False) and not UPDATE_CHECK_DISABLED:
        # Try update check - if ANYTHING fails, just skip it and launch app
        try:
            if UPDATE_ENABLED:
                try:
                    handle_updates()
                except Exception as e:
                    # Silently skip update check if it fails
                    print(f"Update check skipped: {e}")
        except Exception as e:
            # Even if update system fails to load, continue
            print(f"Update system unavailable, continuing: {e}")
    
    # Auto-launch browser when running as frozen exe
    if getattr(sys, "frozen", False):
        def _open_browser():
            time.sleep(2.0)
            try:
                webbrowser.open_new("http://127.0.0.1:5000")
            except Exception:
                pass  # Browser launch is optional
        threading.Thread(target=_open_browser, daemon=True).start()

    # Always launch the app, regardless of update check
    try:
        print("Starting Camera Calibrator application...")
        runpy.run_module("app", run_name="__main__")
    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\nFatal error launching app: {e}")
        import traceback
        traceback.print_exc()
        print("\n" + "="*60)
        input("Press Enter to exit...")  # Keep window open to see error
        sys.exit(1)
