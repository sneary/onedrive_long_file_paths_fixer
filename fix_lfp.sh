#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

########################################################################################################
# fix_lfp.sh
#
# Script to identify and optionally move long path files.
# 
# Meant to clear away files in onedrive directories that are too long for onedrive to handle.
# Files are simply moved to a folder called LFP in the users home directory 
# keeping their same long relative paths. These paths can be manually changed by the user
# later if they wish to store these files on onedrive again.
#
# Usage: ./fix_lfp.sh -t "/path/to/scan" [--move]
#
# Default behavior is SCAN ONLY (Dry Run).
########################################################################################################

set -o pipefail
unset findlong

# Cleanup function
function finish() {
    [[ -z "$findlong" ]] || rm -f "$findlong"
    [[ ! $(pgrep "caffeinate") ]] || killall "caffeinate"
    exit 0
}
trap finish HUP INT QUIT TERM

# Prevent sleep
(caffeinate -sim -t 3600) &
disown

usage() {
    echo "Usage: $0 -t <target_folder> [-m|--move]"
    echo "  -t, --target    Target folder to scan (Required)"
    echo "  -m, --move      Move files to ~/LFP (Destroys source!)"
    echo "  -h, --help      Show this help"
    exit 1
}

# Parse Args
TARGET_FOLDER=""
DO_MOVE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--target) TARGET_FOLDER="$2"; shift ;;
        -m|--move) DO_MOVE=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

if [[ -z "$TARGET_FOLDER" ]]; then
    echo "Error: Target folder is required."
    usage
fi

# Normalize Target Folder (strip trailing slash)
TARGET_FOLDER="${TARGET_FOLDER%/}"

if [[ ! -d "$TARGET_FOLDER" ]]; then
    echo "Error: Target directory does not exist: $TARGET_FOLDER"
    exit 1
fi

# --- SCAN PHASE ---
echo "--- Phase 1: Scanning ---"
echo "Target: $TARGET_FOLDER"
echo "Date:   $(date)"

# Get user for log paths (macOS scutil check or fallback)
if command -v scutil >/dev/null; then
    LOGGED_IN_USER="$(scutil <<<"show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"
else
    LOGGED_IN_USER="$USER"
fi

# Setup Log
LOG_DIR="/var/log/onedrive-findlogs"
if [[ ! -w "/var/log" ]]; then
    LOG_DIR="/tmp/onedrive-findlogs"
fi
[[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"

DATE_STR="$(date +%m%d%y-%H%M)"
LOG_FILE="$LOG_DIR/onedrive-findlonglog-$DATE_STR"
REPORT_FILE="/Users/$LOGGED_IN_USER/Desktop/LFP_Report-$DATE_STR.csv"
if [[ ! -d "/Users/$LOGGED_IN_USER/Desktop" ]]; then
     REPORT_FILE="$HOME/LFP_Report-$DATE_STR.csv"
fi

echo "Lfp" > "$LOG_FILE"
echo "Lfp" > "$REPORT_FILE"

TEMP_LIST="$(mktemp)"
findlong="$TEMP_LIST"

# Find files
find "$TARGET_FOLDER" -name "*" -print 2>/dev/null > "$TEMP_LIST"

FOUND_COUNT=0
# Array to hold found paths for processing
declare -a LONG_FILES

# Read and filter (Compatible with Bash 3.2+)
while IFS= read -r line; do
    if [[ ${#line} -gt 376 ]]; then
        ((FOUND_COUNT++))
        LONG_FILES+=("$line")
        echo "\"$line\"" >> "$REPORT_FILE"
    fi
done < "$TEMP_LIST"

# Sort LONG_FILES by length (descending) so we move deepest children BEFORE parents
if [[ "$FOUND_COUNT" -gt 0 ]]; then
    printf "%s\n" "${LONG_FILES[@]}" | awk '{ print length, $0 }' | sort -nr | cut -d" " -f2- > "$TEMP_LIST.sorted"
    
    # Reset array and read back sorted (Bash 3.2 compatible)
    LONG_FILES=()
    while IFS= read -r line; do
        LONG_FILES+=("$line")
    done < "$TEMP_LIST.sorted"
    rm -f "$TEMP_LIST.sorted"
fi

echo "Scan Complete."
echo "Found $FOUND_COUNT files exceeding 376 characters."
echo "Report saved to: $REPORT_FILE"

if [[ "$FOUND_COUNT" -eq 0 ]]; then
    echo "No long paths found. Exiting."
    finish
fi

# --- MOVE PHASE ---
if [[ "$DO_MOVE" == "true" ]]; then
    echo ""
    echo "--- Phase 2: Moving Files ---"
    
    LFP_DIR="$HOME/LFP"
    [[ -d "$LFP_DIR" ]] || mkdir -p "$LFP_DIR"
    
    for path in "${LONG_FILES[@]}"; do
        # Check if file still exists (it might have been moved if it was inside a moved directory)
        if [[ ! -e "$path" ]]; then
            echo "Skipping (already moved/gone): $path"
            continue
        fi

        # Calculate destination
        # remove prefix $TARGET_FOLDER
        REL_PATH="${path#$TARGET_FOLDER}"
        # If REL_PATH starts with /, remove it
        REL_PATH="${REL_PATH#/}"
        
        NEW_PATH="$LFP_DIR/$REL_PATH"
        
        echo "Moving: .../$REL_PATH"
        
        mkdir -p "$(dirname "$NEW_PATH")"
        
        rsync -a --remove-source-files "$path" "$NEW_PATH"
        
        if [[ -d "$path" ]]; then
             rmdir "$path" 2>/dev/null
        fi
    done
    
    echo "Move Complete."
else
    echo ""
    echo "--- Dry Run Complete ---"
    echo "To move these files, run the command again with --move"
fi

finish
