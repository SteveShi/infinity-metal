#!/bin/bash
# ==============================================================================
# PST:EE Metal Backend - One-Click Installer
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DYLIB_TARGET="$PROJECT_DIR/build/libPSTMetal.dylib"

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
    echo "Please specify your game location by setting GAME_APP, for example:"
    echo '  GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" make install'
    exit 1
fi

GAME_APP="$FOUND_APP"
GAME_DIR="$(dirname "$GAME_APP")"
GAME_BIN_DIR="$GAME_APP/Contents/MacOS"
LAUNCHER_CMD="$GAME_DIR/Planescape Torment (Metal).command"

echo "=================================================="
echo " Planescape Torment: Enhanced Edition Metal Mod"
echo " Installation & Patch Script"
echo "=================================================="
echo "📍 Detected Game App: $GAME_APP"

# 1. Build libPSTMetal.dylib if not already built
if [ ! -f "$DYLIB_TARGET" ]; then
    echo "🔨 Building Universal Metal Dynamic Library (libPSTMetal.dylib)..."
    make -C "$PROJECT_DIR"
fi

# 2. Copy dylib into game bundle
echo "📦 Deploying libPSTMetal.dylib to game bundle..."
cp "$DYLIB_TARGET" "$GAME_BIN_DIR/libPSTMetal.dylib"
codesign --force --sign - "$GAME_BIN_DIR/libPSTMetal.dylib" 2>/dev/null || true

# 3. Re-sign game binary with ad-hoc entitlements
echo "🔐 Re-signing game binary with ad-hoc DYLD injection entitlements..."
GAME_APP="$GAME_APP" "$SCRIPT_DIR/resign.sh"

# 4. Create one-click launcher in game folder
APP_BASENAME="$(basename "$GAME_APP")"
echo "🚀 Creating one-click double-clickable launcher..."
cat << EOF > "$LAUNCHER_CMD"
#!/bin/bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
export DYLD_INSERT_LIBRARIES="\$DIR/$APP_BASENAME/Contents/MacOS/libPSTMetal.dylib"
exec "\$DIR/$APP_BASENAME/Contents/MacOS/Planescape Torment - Enhanced Edition" "\$@"
EOF
chmod +x "$LAUNCHER_CMD"

echo ""
echo "=================================================="
echo "✅ Installation & Patching Complete!"
echo "=================================================="
echo "You can now run the game with Native Metal rendering in any of these ways:"
echo "1. Double-click '$LAUNCHER_CMD'"
echo "2. Run 'make test' in the project directory"
echo "3. In GOG Galaxy / Steam: Set Custom Executable to '$LAUNCHER_CMD'"
echo "=================================================="
