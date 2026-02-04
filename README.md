# OneDrive Long File Path Fixer (`fix_lfp`)

A macOS utility script to solve OneDrive sync issues caused by file paths exceeding the character limit.

## The Problem
OneDrive on macOS has difficulty syncing files with extremely long paths (often deep folder hierarchies). These files can block the sync process entirely.

## The Solution
`fix_lfp.sh` scans a target directory for these problematic files and moves them out of OneDrive into a local safe folder (`~/LFP`), preserving their relative directory structure. This allows OneDrive to resume syncing while keeping your files safe.

## Features
*   **Safe by Default**: Runs in "Dry Run" mode unless explicitly told to move files.
*   **Deep Path Priority**: Automatically handles the deepest files first to prevent errors when moving parent folders.
*   **Preserves Structure**: Files are moved to `~/LFP` retaining their original folder hierarchy, making it easy to restore them later if needed.
*   **Reporting**: Generates a CSV report of all affected files on your Desktop.

## Usage

### 1. Download & Permissions
Download the script and make it executable:
```bash
chmod +x fix_lfp.sh
```

### 2. Scan (Dry Run)
Run the script pointing to your OneDrive folder (or subfolder). This will **only list** the files found and generate a report.

```bash
./fix_lfp.sh -t "/Users/yourname/OneDrive - Personal"
```

### 3. Move Files
To actually move the files to `~/LFP`, add the `--move` flag:

```bash
./fix_lfp.sh -t "/Users/yourname/OneDrive - Personal" --move
```

## Requirements
*   macOS (uses `scutil` and `caffeinate`)
*   Bash 3.2+ (Standard on macOS)

## Disclaimer
This script moves files. While it is designed to be safe (using `rsync`), you should always ensure your data is backed up before running bulk file operations. Use at your own risk.
