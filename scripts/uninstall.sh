#!/bin/bash
# ==============================================================================
# Infinity Engine EE Metal Backend - Universal Multi-Game Uninstaller
# Author: Steve Shi / 轩楝 (zh-Hans)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================================="
echo " Infinity Engine Enhanced Edition — Apple Metal Mod"
echo " Universal Multi-Game Uninstaller & Restore Script"
echo "=================================================="

GAME_SPECS=(
    "Baldur's Gate: Enhanced Edition|Baldur's Gate (Metal).command|/Applications/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app:/Applications/Baldur's Gate - Enhanced Edition.app:$HOME/Applications/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app:$HOME/Applications/Baldur's Gate - Enhanced Edition.app:$HOME/Library/Application Support/Steam/steamapps/common/Baldur's Gate Enhanced Edition/Baldur's Gate - Enhanced Edition.app"
    "Baldur's Gate II: Enhanced Edition|Baldur's Gate II (Metal).command|/Applications/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app:/Applications/BaldursGateIIEnhancedEdition.app:$HOME/Applications/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app:$HOME/Applications/BaldursGateIIEnhancedEdition.app:$HOME/Library/Application Support/Steam/steamapps/common/Baldur's Gate II Enhanced Edition/BaldursGateIIEnhancedEdition.app"
    "Icewind Dale: Enhanced Edition|Icewind Dale (Metal).command|/Applications/Icewind Dale Enhanced Edition/IcewindDale.app:/Applications/Icewind Dale Enhanced Edition/Icewind Dale - Enhanced Edition.app:/Applications/IcewindDale.app:$HOME/Applications/Icewind Dale Enhanced Edition/IcewindDale.app:$HOME/Library/Application Support/Steam/steamapps/common/Icewind Dale Enhanced Edition/IcewindDale.app"
    "Planescape Torment: Enhanced Edition|Planescape Torment (Metal).command|/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app:/Applications/Planescape Torment - Enhanced Edition.app:$HOME/Applications/Planescape Torment - Enhanced Edition/Planescape Torment - Enhanced Edition.app:$HOME/Applications/Planescape Torment - Enhanced Edition.app:$HOME/Library/Application Support/Steam/steamapps/common/Planescape Torment Enhanced Edition/Planescape Torment - Enhanced Edition.app"
)

CUSTOM_APP="${GAME_APP:-}"
UNINSTALLED_COUNT=0

uninstall_from_game() {
    local game_title="$1"
    local launcher_name="$2"
    local game_app="$3"

    echo ""
    echo "--------------------------------------------------"
    echo "🗑️ Restoring: $game_title ($game_app)"

    local app_dir="$(dirname "$game_app")"
    local bin_dir="$game_app/Contents/MacOS"
    local launcher_path="$app_dir/$launcher_name"
    local game_name="$(basename "$game_app")"
    local backup_sig="$PROJECT_DIR/build/signatures/$game_name/_CodeSignature"

    # Remove dylibs (both new and old names)
    rm -f "$bin_dir/libInfinityMetal.dylib" "$bin_dir/libPSTMetal.dylib"
    rm -f "$launcher_path" "$app_dir/Planescape Torment (Metal).command"

    # Restore code signature if backup exists
    if [ -d "$backup_sig" ]; then
        echo "🔄 Restoring original code signature..."
        rm -rf "$game_app/Contents/_CodeSignature"
        cp -R "$backup_sig" "$game_app/Contents/_CodeSignature"
        codesign --force --sign - "$game_app" 2>/dev/null || true
    else
        echo "ℹ️ Re-signing game cleanly..."
        codesign --force --sign - "$game_app" 2>/dev/null || true
    fi

    echo "✅ $game_title restored to stock state."
    UNINSTALLED_COUNT=$((UNINSTALLED_COUNT + 1))
}

if [ -n "$CUSTOM_APP" ]; then
    if [ ! -d "$CUSTOM_APP" ]; then
        echo "❌ Error: Specified GAME_APP does not exist: $CUSTOM_APP"
        exit 1
    fi
    uninstall_from_game "Custom Infinity Engine Game" "Launch (Metal).command" "$CUSTOM_APP"
else
    echo "🔍 Scanning for installed Infinity Engine EE games..."
    for spec in "${GAME_SPECS[@]}"; do
        IFS='|' read -r title launcher paths <<< "$spec"
        IFS=':' read -ra cand_array <<< "$paths"
        for cand in "${cand_array[@]}"; do
            if [ -n "$cand" ] && [ -d "$cand" ]; then
                uninstall_from_game "$title" "$launcher" "$cand"
                break
            fi
        done
    done
fi

echo ""
echo "=================================================="
echo "✅ Uninstallation Complete! Processed $UNINSTALLED_COUNT game(s)."
echo "=================================================="
