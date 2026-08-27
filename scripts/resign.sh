#!/bin/bash
# ==============================================================================
# Ad-hoc re-sign PST:EE to allow DYLD_INSERT_LIBRARIES injection
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENTITLEMENTS="$SCRIPT_DIR/entitlements.plist"
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
    echo "[PSTMetal] ❌ Error: Planescape Torment: Enhanced Edition not found."
    echo "Please specify your game application path via:"
    echo '  GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" ./scripts/resign.sh'
    exit 1
fi

GAME_APP="$FOUND_APP"
GAME_BIN="$GAME_APP/Contents/MacOS/Planescape Torment - Enhanced Edition"

# Verify entitlements
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "[PSTMetal] ERROR: entitlements.plist not found at $ENTITLEMENTS"
    exit 1
fi

# Backup original signature (only if not already backed up)
mkdir -p "$PROJECT_DIR/build"
if [ ! -d "$BACKUP_SIG" ] && [ -d "$GAME_APP/Contents/_CodeSignature" ]; then
    echo "[PSTMetal] Backing up original code signature..."
    cp -R "$GAME_APP/Contents/_CodeSignature" "$BACKUP_SIG"
    echo "[PSTMetal] Backup saved to: $BACKUP_SIG"
fi

echo "[PSTMetal] Re-signing game with ad-hoc signature at $GAME_APP..."

# Also re-sign helper dylibs if present
if [ -f "$GAME_APP/Contents/MacOS/libsteam_api.dylib" ]; then
    codesign --force --sign - "$GAME_APP/Contents/MacOS/libsteam_api.dylib" 2>/dev/null || true
fi
if [ -f "$GAME_APP/Contents/MacOS/libPSTMetal.dylib" ]; then
    codesign --force --sign - "$GAME_APP/Contents/MacOS/libPSTMetal.dylib" 2>/dev/null || true
fi

# Re-sign the main binary with entitlements
codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --deep \
    "$GAME_APP"

echo "[PSTMetal] ✅ Re-signing complete!"
