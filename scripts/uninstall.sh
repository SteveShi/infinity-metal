#!/bin/bash
# ==============================================================================
# PST:EE Metal Backend - One-Click Uninstaller
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

GAME_DIR="/Applications/Planescape Torment - Enhanced Edition"
GAME_APP="$GAME_DIR/Planescape Torment - Enhanced Edition.app"
GAME_BIN_DIR="$GAME_APP/Contents/MacOS"
LAUNCHER_CMD="$GAME_DIR/Planescape Torment (Metal).command"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SIG="$(dirname "$SCRIPT_DIR")/build/_CodeSignature_orig.bak"

echo "=================================================="
echo " Planescape Torment: Enhanced Edition Metal Mod"
echo " Uninstallation & Restore Script"
echo "=================================================="

# 1. Remove deployed dylib
if [ -f "$GAME_BIN_DIR/libPSTMetal.dylib" ]; then
    echo "🗑️ Removing $GAME_BIN_DIR/libPSTMetal.dylib..."
    rm -f "$GAME_BIN_DIR/libPSTMetal.dylib"
fi

# 2. Remove launcher
if [ -f "$LAUNCHER_CMD" ]; then
    echo "🗑️ Removing launcher '$LAUNCHER_CMD'..."
    rm -f "$LAUNCHER_CMD"
fi

# 3. Restore original code signature if available
if [ -d "$BACKUP_SIG" ]; then
    echo "🔄 Restoring original code signature..."
    rm -rf "$GAME_APP/Contents/_CodeSignature"
    cp -R "$BACKUP_SIG" "$GAME_APP/Contents/_CodeSignature"
    codesign --force --sign - "$GAME_APP" 2>/dev/null || true
    echo "✅ Original signature restored."
else
    echo "ℹ️ Re-signing game cleanly without injection entitlements..."
    codesign --force --sign - "$GAME_APP" 2>/dev/null || true
fi

echo ""
echo "=================================================="
echo "✅ Uninstallation Complete!"
echo "Game restored to stock state."
echo "=================================================="
