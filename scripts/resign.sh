#!/bin/bash
# Ad-hoc re-sign PST:EE to allow DYLD_INSERT_LIBRARIES injection
# This removes the original Beamdog/GOG signature and replaces it with
# a local ad-hoc signature that permits dylib injection.

set -euo pipefail

GAME_APP="/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app"
GAME_BIN="$GAME_APP/Contents/MacOS/Planescape Torment - Enhanced Edition"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS="$SCRIPT_DIR/entitlements.plist"
BACKUP_SIG="$(dirname "$SCRIPT_DIR")/build/_CodeSignature_orig.bak"

# Verify game exists
if [ ! -f "$GAME_BIN" ]; then
    echo "[PSTMetal] ERROR: Game binary not found at:"
    echo "  $GAME_BIN"
    exit 1
fi

# Verify entitlements
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "[PSTMetal] ERROR: entitlements.plist not found at $ENTITLEMENTS"
    exit 1
fi

# Backup original signature (only if not already backed up)
if [ ! -d "$BACKUP_SIG" ]; then
    echo "[PSTMetal] Backing up original code signature..."
    cp -R "$GAME_APP/Contents/_CodeSignature" "$BACKUP_SIG"
    echo "[PSTMetal] Backup saved to: $BACKUP_SIG"
else
    echo "[PSTMetal] Original signature backup already exists, skipping backup."
fi

echo "[PSTMetal] Re-signing game with ad-hoc signature..."
echo "[PSTMetal] Entitlements: $ENTITLEMENTS"

# Also re-sign the Steam/GOG helper dylib if present
if [ -f "$GAME_APP/Contents/MacOS/libsteam_api.dylib" ]; then
    codesign --force --sign - "$GAME_APP/Contents/MacOS/libsteam_api.dylib" 2>/dev/null || true
fi

# Re-sign the main binary with entitlements
codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --deep \
    "$GAME_APP"

echo ""
echo "[PSTMetal] ✅ Re-signing complete!"
echo "[PSTMetal] The game now accepts DYLD_INSERT_LIBRARIES injection."
echo "[PSTMetal] To restore the original signature:"
echo "  mv '$BACKUP_SIG' '$GAME_APP/Contents/_CodeSignature'"
echo "  codesign --force --sign - '$GAME_APP'"
echo ""
echo "[PSTMetal] Or verify game files through GOG Galaxy to fully restore."
