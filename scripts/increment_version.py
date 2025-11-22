#!/usr/bin/env python3
"""
Increment semantic version number.
Handles automatic rollover: 1.0.9 -> 1.1.0, 1.9.9 -> 2.0.0
"""
import sys

def increment_version(version_str):
    """Increment patch version with automatic rollover."""
    try:
        parts = version_str.split('.')
        if len(parts) != 3:
            raise ValueError("Version must be in format MAJOR.MINOR.PATCH")
        
        major = int(parts[0])
        minor = int(parts[1])
        patch = int(parts[2])
        
        # Increment patch
        patch += 1
        
        # Rollover logic
        if patch > 9:
            patch = 0
            minor += 1
            if minor > 9:
                minor = 0
                major += 1
                    
        return f"{major}.{minor}.{patch}"
    except (ValueError, IndexError) as e:
        print(f"Error: Invalid version format '{version_str}': {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: increment_version.py <version>", file=sys.stderr)
        print("Example: increment_version.py 1.0.0", file=sys.stderr)
        sys.exit(1)
    
    current_version = sys.argv[1]
    new_version = increment_version(current_version)
    print(new_version)

