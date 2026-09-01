#!/bin/bash
# ==============================================================================
# Infinity Engine EE Metal Backend Launcher
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DYLIB_PATH="$PROJECT_DIR/build/libInfinityMetal.dylib"

if [ ! -f "$DYLIB_PATH" ]; then
    echo "[InfinityMetal] Building libInfinityMetal.dylib..."
    make -C "$PROJECT_DIR"
fi

# Detect installed games
GAME_NAMES=()
GAME_BINS=()

check_add_game() {
    local name="$1"
    local app_path="$2"
    if [ -d "$app_path" ]; then
        local bin_dir="$app_path/Contents/MacOS"
        for f in "$bin_dir"/*; do
            if [ -f "$f" ] && [ -x "$f" ]; then
                local fname="$(basename "$f")"
                if [[ "$fname" != *.dylib ]] && [[ "$fname" != *.sh ]]; then
                    GAME_NAMES+=("$name")
                    GAME_BINS+=("$f")
                    break
                fi
            fi
        done
    fi
}

check_add_game "Baldur's Gate: Enhanced Edition" "/Applications/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app"
check_add_game "Baldur's Gate II: Enhanced Edition" "/Applications/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app"
check_add_game "Icewind Dale: Enhanced Edition" "/Applications/Icewind Dale Enhanced Edition/IcewindDale.app"
check_add_game "Planescape Torment: Enhanced Edition" "/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app"

if [ "${#GAME_BINS[@]}" -eq 0 ]; then
    echo "[InfinityMetal] ❌ No Infinity Engine games found in /Applications."
    exit 1
fi

SELECTED_INDEX=0

if [ "${#GAME_BINS[@]}" -gt 1 ]; then
    echo "=================================================="
    echo " Select Infinity Engine Game to Launch (with Metal):"
    echo "=================================================="
    for i in "${!GAME_NAMES[@]}"; do
        echo "  $((i+1)). ${GAME_NAMES[$i]}"
    done
    echo "=================================================="
    read -rp "Enter choice [1-${#GAME_BINS[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#GAME_BINS[@]}" ]; then
        SELECTED_INDEX=$((choice - 1))
    else
        echo "Invalid selection, launching ${GAME_NAMES[0]}..."
        SELECTED_INDEX=0
    fi
fi

CHOSEN_NAME="${GAME_NAMES[$SELECTED_INDEX]}"
CHOSEN_BIN="${GAME_BINS[$SELECTED_INDEX]}"

echo "[InfinityMetal] Launching $CHOSEN_NAME with Native Metal..."
export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"
exec "$CHOSEN_BIN" "$@"
