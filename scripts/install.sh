#!/bin/bash
# ==============================================================================
# PST:EE Metal Backend - One-Click Installer
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GAME_DIR="/Applications/Planescape Torment - Enhanced Edition"
GAME_APP="$GAME_DIR/Planescape Torment - Enhanced Edition.app"
GAME_BIN_DIR="$GAME_APP/Contents/MacOS"
GAME_BIN="$GAME_BIN_DIR/Planescape Torment - Enhanced Edition"
DYLIB_TARGET="$PROJECT_DIR/build/libPSTMetal.dylib"
LAUNCHER_CMD="$GAME_DIR/Planescape Torment (Metal).command"

echo "=================================================="
echo " Planescape Torment: Enhanced Edition Metal Mod"
echo " Installation & Patch Script"
echo "=================================================="

# 1. Verify game installation
if [ ! -d "$GAME_APP" ]; then
    echo "❌ Error: Game not found at:"
    echo "   $GAME_APP"
    echo "Please make sure Planescape Torment: Enhanced Edition is installed in /Applications."
    exit 1
fi

# 2. Build libPSTMetal.dylib if not already built
if [ ! -f "$DYLIB_TARGET" ]; then
    echo "🔨 Building Universal Metal Dynamic Library (libPSTMetal.dylib)..."
    make -C "$PROJECT_DIR"
fi

# 3. Copy dylib into game bundle
echo "📦 Deploying libPSTMetal.dylib to game bundle..."
cp "$DYLIB_TARGET" "$GAME_BIN_DIR/libPSTMetal.dylib"
codesign --force --sign - "$GAME_BIN_DIR/libPSTMetal.dylib" 2>/dev/null || true

# 4. Re-sign game binary with ad-hoc entitlements
echo "🔐 Re-signing game binary with ad-hoc DYLD injection entitlements..."
"$SCRIPT_DIR/resign.sh"

# 5. Create one-click launcher in game folder
echo "🚀 Creating one-click double-clickable launcher in game folder..."
cat << 'EOF' > "$LAUNCHER_CMD"
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export DYLD_INSERT_LIBRARIES="$DIR/Planescape Torment - Enhanced Edition.app/Contents/MacOS/libPSTMetal.dylib"
exec "$DIR/Planescape Torment - Enhanced Edition.app/Contents/MacOS/Planescape Torment - Enhanced Edition" "$@"
EOF
chmod +x "$LAUNCHER_CMD"

echo ""
echo "=================================================="
echo "✅ Installation & Patching Complete!"
echo "=================================================="
echo "You can now run the game with Native Metal rendering in any of these ways:"
echo "1. Double-click '$LAUNCHER_CMD'"
echo "2. Run 'make test' in the project directory"
echo "3. In GOG Galaxy: Set Custom Executable to '$LAUNCHER_CMD'"
echo "=================================================="
