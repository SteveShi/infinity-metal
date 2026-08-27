#!/bin/bash
# ==============================================================================
# PST:EE Metal Backend Launcher
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DYLIB_PATH="$PROJECT_DIR/build/libPSTMetal.dylib"

# Auto-detect game application path
CANDIDATE_PATHS=(
    "${GAME_APP:-}"
    "/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app"
    "/Applications/Planescape Torment - Enhanced Edition.app"
    "$HOME/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app"
    "$HOME/Applications/Planescape Torment - Enhanced Edition.app"
    "$HOME/Library/Application Support/Steam/steamapps/common/Planescape Torment Enhanced Edition/Planescape Torment - Enhanced Edition.app"
)

FOUND_APP=""
for p in "${CANDIDATE_PATHS[@]}"; do
    if [ -n "$p" ] && [ -d "$p" ]; then
        FOUND_APP="$p"
        break
    fi
done

if [ -z "$FOUND_APP" ]; then
    echo "[PSTMetal] ❌ Error: Planescape Torment: Enhanced Edition not found in standard macOS locations."
    echo "Please specify your game location by setting GAME_APP, for example:"
    echo '  GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" ./scripts/launch_metal.sh'
    exit 1
fi

GAME_APP="$FOUND_APP"
GAME_BIN="$GAME_APP/Contents/MacOS/Planescape Torment - Enhanced Edition"

# Verify dylib exists
if [ ! -f "$DYLIB_PATH" ]; then
    echo "[PSTMetal] Building libPSTMetal.dylib..."
    make -C "$PROJECT_DIR"
fi

echo "[PSTMetal] Launching PST:EE with Metal rendering backend..."
echo "[PSTMetal] Game:  $GAME_APP"
echo "[PSTMetal] Dylib: $DYLIB_PATH"

export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"
exec "$GAME_BIN" "$@"
