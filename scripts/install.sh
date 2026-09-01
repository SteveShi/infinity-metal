#!/bin/bash
# ==============================================================================
# Infinity Engine EE Metal Backend - Universal One-Click Multi-Game Installer
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DYLIB_TARGET="$PROJECT_DIR/build/libInfinityMetal.dylib"

echo "=================================================="
echo " Infinity Engine Enhanced Edition — Apple Metal Mod"
echo " Universal Multi-Game Installer & Patch Script"
echo "=================================================="

# 1. Build Universal Binary if not already present
if [ ! -f "$DYLIB_TARGET" ]; then
    echo "🔨 Building Universal Metal Dynamic Library (libInfinityMetal.dylib)..."
    make -C "$PROJECT_DIR"
fi

# 2. Define known game definitions
# Format: "ShortName|LauncherName|CandidatePaths..."
GAME_SPECS=(
    "Baldur's Gate: Enhanced Edition|Baldur's Gate (Metal).command|/Applications/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app:/Applications/Baldur's Gate - Enhanced Edition.app:$HOME/Applications/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app:$HOME/Applications/Baldur's Gate - Enhanced Edition.app:$HOME/Library/Application Support/Steam/steamapps/common/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app"
    "Baldur's Gate II: Enhanced Edition|Baldur's Gate II (Metal).command|/Applications/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app:/Applications/BaldursGateIIEnhancedEdition.app:$HOME/Applications/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app:$HOME/Applications/BaldursGateIIEnhancedEdition.app:$HOME/Library/Application Support/Steam/steamapps/common/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app"
    "Icewind Dale: Enhanced Edition|Icewind Dale (Metal).command|/Applications/Icewind Dale Enhanced Edition/IcewindDale.app:/Applications/Icewind Dale Enhanced Edition/Icewind Dale - Enhanced Edition.app:/Applications/IcewindDale.app:$HOME/Applications/Icewind Dale Enhanced Edition/IcewindDale.app:$HOME/Library/Application Support/Steam/steamapps/common/Icewind Dale Enhanced Edition/IcewindDale.app"
    "Planescape Torment: Enhanced Edition|Planescape Torment (Metal).command|/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app:/Applications/Planescape Torment - Enhanced Edition.app:$HOME/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app:$HOME/Applications/Planescape Torment - Enhanced Edition.app:$HOME/Library/Application Support/Steam/steamapps/common/Planescape Torment Enhanced Edition/Planescape Torment - Enhanced Edition.app"
)

# If GAME_APP is explicitly set by user, only install to that game
CUSTOM_APP="${GAME_APP:-}"
INSTALLED_COUNT=0

install_to_game() {
    local game_title="$1"
    local launcher_name="$2"
    local game_app="$3"

    echo ""
    echo "--------------------------------------------------"
    echo "🎮 Configuring: $game_title"
    echo "📍 Path: $game_app"

    local app_dir="$(dirname "$game_app")"
    local bin_dir="$game_app/Contents/MacOS"
    local launcher_path="$app_dir/$launcher_name"

    # Find main executable
    local main_bin=""
    for f in "$bin_dir"/*; do
        if [ -f "$f" ] && [ -x "$f" ]; then
            local fname="$(basename "$f")"
            if [[ "$fname" != *.dylib ]] && [[ "$fname" != *.sh ]]; then
                main_bin="$fname"
                break
            fi
        fi
    done

    if [ -z "$main_bin" ]; then
        echo "⚠️ Warning: Could not find main executable in $bin_dir, skipping."
        return
    fi

    # 1. Copy dylib
    echo "📦 Deploying libInfinityMetal.dylib..."
    cp "$DYLIB_TARGET" "$bin_dir/libInfinityMetal.dylib"
    codesign --force --sign - "$bin_dir/libInfinityMetal.dylib" 2>/dev/null || true

    # 2. Re-sign App with injection entitlements
    "$SCRIPT_DIR/resign.sh" "$game_app"

    # 3. Create double-clickable launcher
    local app_basename="$(basename "$game_app")"
    echo "🚀 Creating launcher: $launcher_path"
    cat << EOF > "$launcher_path"
#!/bin/bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
export DYLD_INSERT_LIBRARIES="\$DIR/$app_basename/Contents/MacOS/libInfinityMetal.dylib"
exec "\$DIR/$app_basename/Contents/MacOS/$main_bin" "\$@"
EOF
    chmod +x "$launcher_path"

    echo "✅ $game_title successfully configured!"
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
}

if [ -n "$CUSTOM_APP" ]; then
    if [ ! -d "$CUSTOM_APP" ]; then
        echo "❌ Error: Specified GAME_APP does not exist: $CUSTOM_APP"
        exit 1
    fi
    install_to_game "Custom Infinity Engine Game" "Launch (Metal).command" "$CUSTOM_APP"
else
    echo "🔍 Scanning macOS applications for Infinity Engine EE games..."
    for spec in "${GAME_SPECS[@]}"; do
        IFS='|' read -r title launcher paths <<< "$spec"
        IFS=':' read -ra cand_array <<< "$paths"
        for cand in "${cand_array[@]}"; do
            if [ -n "$cand" ] && [ -d "$cand" ]; then
                install_to_game "$title" "$launcher" "$cand"
                break
            fi
        done
    done
fi

echo ""
echo "=================================================="
if [ "$INSTALLED_COUNT" -gt 0 ]; then
    echo "🎉 Installation complete! Successfully patched $INSTALLED_COUNT game(s)."
    echo "You can now run any patched game via its '(Metal).command' launcher!"
else
    echo "❌ No Infinity Engine EE games found in standard locations."
    echo "Please specify your game path via:"
    echo '  GAME_APP="/path/to/Game.app" make install'
fi
echo "=================================================="
