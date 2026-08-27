#!/bin/bash
# PST:EE Metal Backend Launcher
# Usage: ./launch_metal.sh
# Or set as GOG Galaxy custom launch command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GAME_DIR="/Applications/Planescape Torment - Enhanced Edition"
GAME_APP="$GAME_DIR/Planescape Torment - Enhanced Edition.app"
GAME_BIN="$GAME_APP/Contents/MacOS/Planescape Torment - Enhanced Edition"
DYLIB_PATH="$PROJECT_DIR/build/libPSTMetal.dylib"

# Verify dylib exists
if [ ! -f "$DYLIB_PATH" ]; then
    echo "[PSTMetal] ERROR: libPSTMetal.dylib not found at $DYLIB_PATH"
    echo "[PSTMetal] Run 'make' in $PROJECT_DIR first."
    exit 1
fi

# Verify game exists
if [ ! -f "$GAME_BIN" ]; then
    echo "[PSTMetal] ERROR: Game not found at $GAME_BIN"
    exit 1
fi

echo "[PSTMetal] Launching PST:EE with Metal rendering backend..."
echo "[PSTMetal] dylib: $DYLIB_PATH"

export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"
exec "$GAME_BIN" "$@"
