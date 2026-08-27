#!/bin/bash
# ==============================================================================
# PST:EE Metal Backend - One-Click Uninstaller
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SIG="$PROJECT_DIR/build/_CodeSignature_orig.bak"

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
    echo "❌ Error: Planescape Torment: Enhanced Edition not found in standard macOS locations."
    echo "Please specify your game location via:"
    echo '  GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" make uninstall'
    exit 1
fi

GAME_APP="$FOUND_APP"
GAME_DIR="$(dirname "$GAME_APP")"
GAME_BIN_DIR="$GAME_APP/Contents/MacOS"
LAUNCHER_CMD="$GAME_DIR/Planescape Torment (Metal).command"

echo "=================================================="
echo " Planescape Torment: Enhanced Edition Metal Mod"
echo " Uninstallation & Restore Script"
echo "=================================================="
echo "📍 Target Game App: $GAME_APP"

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
