#!/usr/bin/env python3
"""
Update checker for Camera Calibrator.
Checks GitHub releases and compares versions.
"""

import requests
import sys
from pathlib import Path
from packaging import version


# GitHub repository info
REPO_OWNER = "aiigoradam"
REPO_NAME = "camera-calibrator"
GITHUB_API_URL = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"


def get_current_version():
    """Get current application version from version.txt (format: 1.0.1-68bc3ee)."""
    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).parent
        version_file = exe_dir / "_internal" / "version.txt"
    else:
        version_file = Path(__file__).parent / "version.txt"

    if version_file.exists():
        try:
            version_str = version_file.read_text().strip()
            return version_str
        except OSError as e:
            print(f"Error reading version file: {e}")
            return "1.0.0"

    return "1.0.0"


def get_current_build_tag():
    """Get current build tag from version_info.txt if available (deprecated)."""
    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).parent
        version_info_file = exe_dir / "_internal" / "version_info.txt"
    else:
        version_info_file = Path(__file__).parent / "version_info.txt"

    if version_info_file.exists():
        try:
            content = version_info_file.read_text()
            for line in content.split("\n"):
                if line.startswith("Version:"):
                    return line.split(":", 1)[1].strip()
                elif line.startswith("Short Hash:"):
                    return line.split(":", 1)[1].strip()
        except OSError:
            pass

    return None


def check_for_updates():
    """
    Check GitHub for latest release.
    Returns dict with update info or None if no update.
    """
    try:
        response = requests.get(GITHUB_API_URL, timeout=10)
        if response.status_code == 200:
            release_data = response.json()
            latest_tag = release_data["tag_name"]

            latest_version_str = latest_tag.lstrip("v") if latest_tag.startswith("v") else latest_tag
            current_version_str = get_current_version()

            try:
                current_ver_str = (
                    current_version_str.split("-")[0] if "-" in current_version_str else current_version_str
                )
                latest_ver_str = latest_version_str.split("-")[0] if "-" in latest_version_str else latest_version_str

                current_ver = version.parse(current_ver_str)
                latest_ver = version.parse(latest_ver_str)

                if current_ver >= latest_ver:
                    return {"update_available": False}

                download_url = None
                asset_name = None

                for asset in release_data.get("assets", []):
                    if asset["name"].endswith(".zip") and "CameraCalibrator" in asset["name"]:
                        download_url = asset["browser_download_url"]
                        asset_name = asset["name"]
                        break

                if download_url:
                    return {
                        "update_available": True,
                        "current_version": current_version_str,
                        "latest_version": latest_version_str,
                        "latest_tag": latest_tag,
                        "download_url": download_url,
                        "asset_name": asset_name,
                        "release_notes": release_data.get("body", ""),
                        "release_url": release_data.get("html_url", ""),
                        "published_at": release_data.get("published_at", ""),
                    }
            except ValueError as e:
                print(f"Version comparison error: {e}")
                if current_version_str != latest_version_str:
                    for asset in release_data.get("assets", []):
                        if asset["name"].endswith(".zip") and "CameraCalibrator" in asset["name"]:
                            return {
                                "update_available": True,
                                "current_version": current_version_str,
                                "latest_version": latest_version_str,
                                "latest_tag": latest_tag,
                                "download_url": asset["browser_download_url"],
                                "asset_name": asset["name"],
                                "release_notes": release_data.get("body", ""),
                                "release_url": release_data.get("html_url", ""),
                                "published_at": release_data.get("published_at", ""),
                            }

        return {"update_available": False}

    except requests.exceptions.RequestException as e:
        print(f"Update check failed: {e}")
        return {"update_available": False, "error": str(e)}
    except RuntimeError as e:
        print(f"Update check error: {e}")
        return {"update_available": False, "error": str(e)}
