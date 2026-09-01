#!/bin/bash
# ==============================================================================
# Ad-hoc re-sign Infinity Engine EE game for DYLD_INSERT_LIBRARIES injection
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENTITLEMENTS="$SCRIPT_DIR/entitlements.plist"

TARGET_APP="${1:-${GAME_APP:-}}"

if [ -z "$TARGET_APP" ] || [ ! -d "$TARGET_APP" ]; then
    echo "[InfinityMetal] ❌ Error: Game application path not specified or does not exist: $TARGET_APP"
    echo 'Usage: ./scripts/resign.sh "/path/to/Game - Enhanced Edition.app"'
    exit 1
fi

GAME_APP="$TARGET_APP"
GAME_NAME="$(basename "$GAME_APP")"
BACKUP_DIR="$PROJECT_DIR/build/signatures/$GAME_NAME"

# Verify entitlements
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "[InfinityMetal] ❌ Error: entitlements.plist not found at $ENTITLEMENTS"
    exit 1
fi

# Backup original signature (only if not already backed up)
mkdir -p "$BACKUP_DIR"
if [ ! -d "$BACKUP_DIR/_CodeSignature" ] && [ -d "$GAME_APP/Contents/_CodeSignature" ]; then
    echo "[InfinityMetal] 💾 Backing up original code signature for $GAME_NAME..."
    cp -R "$GAME_APP/Contents/_CodeSignature" "$BACKUP_DIR/_CodeSignature"
fi

echo "[InfinityMetal] 🔐 Re-signing $GAME_NAME with ad-hoc entitlements..."

# Re-sign all internal helper dynamic libraries
if [ -d "$GAME_APP/Contents/MacOS" ]; then
    find "$GAME_APP/Contents/MacOS" -type f -name "*.dylib" | while read -r dylib; do
        codesign --force --sign - "$dylib" 2>/dev/null || true
    done
fi

# Re-sign the main app bundle with entitlements
codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --deep \
    "$GAME_APP"

echo "[InfinityMetal] ✅ $GAME_NAME re-signed successfully!"
