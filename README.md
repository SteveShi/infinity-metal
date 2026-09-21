# Infinity Engine: Enhanced Edition — Apple Metal Rendering Backend Mod

[**中文文档 (Simplified Chinese)**](README.zh-CN.md)

---

A unified, high-performance, non-invasive **Apple Metal** native rendering backend mod for all **Infinity Engine: Enhanced Edition** games on macOS.

This mod completely replaces the legacy and deprecated macOS OpenGL 2.1 fixed/programmable pipeline with a native Apple Metal implementation via dynamic library injection (`DYLD_INSERT_LIBRARIES`), unlocking **120Hz ProMotion high refresh rates**, **MetalFX Spatial Upscaling**, reduced CPU overhead, and flawless Retina display rendering on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## 🎮 Supported Games

A single universal binary (`libInfinityMetal.dylib`) automatically detects, patches, and supports all 4 Beamdog Infinity Engine EE titles:

| Game | Version Tested | Default macOS Location |
| :--- | :--- | :--- |
| **Baldur's Gate: Enhanced Edition** (BG1:EE / SoD) | v2.6.6 / v2.7.3 | `/Applications/Baldur's Gate Enhanced Edition/` |
| **Baldur's Gate II: Enhanced Edition** (BG2:EE) | v2.6.6 / v2.7.3 | `/Applications/Baldur's Gate II Enhanced Edition/` |
| **Icewind Dale: Enhanced Edition** (IWD:EE) | v2.6.6 | `/Applications/Icewind Dale Enhanced Edition/` |
| **Planescape Torment: Enhanced Edition** (PST:EE) | v3.1.3 / v3.2.1 | `/Applications/Planescape Torment - Enhanced Edition/` |

---

## Key Features

- **100% Native Apple Metal Translation**: Zero OpenGL system fallbacks. Intercepts all draw calls, shader programs, uniform bindings, and texture uploads directly to the Metal command queue.
- **120Hz ProMotion VSync Support**: Uses `CAMetalLayer` with `displaySyncEnabled` and triple-buffered frame pacing to support 120Hz variable refresh rate displays.
- **MetalFX Spatial Upscaling**: Integrated Apple MetalFX Spatial Scaler pass (`MTLFXSpatialScaler`) with perceptual color processing for crisp rendering on 4K/5K Retina displays.
- **Pixel-Perfect Shader & Font Reproduction**:
  - Implements all 9 Infinity Engine EE shaders directly in Metal Shading Language (`vpDraw`/`fpDraw`, `fpTone`, `fpCatRom`, `vpYUV`/`fpYUV`, `fpYUVGRY`, `fpSprite`, `fpFONT`, `fpSELECT`, `fpSEAM`).
  - Supports 2D Scale & Translate (`uST`) projection mapping.
  - Native single-texture packed YUV 4:2:0 video cutscene playback without color degradation.
  - Dynamic FreeType/NotoSans CJK font glyph cache and legacy BAM font rendering.
- **Pixel-Perfect Input Alignment**: Aligns Retina resolution with native AppKit mouse hit-testing for instant, zero-latency button response.
- **Non-Invasive Architecture**: The original game files are untouched. The mod resides in its own repository and is injected cleanly at launch time.

---

## Requirements & Compatibility

- **macOS**: 11.0 (Big Sur) or higher (macOS 13.0+ required for MetalFX Spatial Upscaler).
- **Architecture**: Universal Binary (`arm64` Apple Silicon + `x86_64` Intel).
- **Game Version**: Beamdog Infinity Engine EE games (GOG / Steam macOS releases).
- **Build Tools**: Xcode Command Line Tools (`clang`, `metal`, `metallib`).

> [!TIP]
> **After Official Game Updates**:
> If Steam or GOG Galaxy updates any game, the official update will overwrite the game bundle signature and remove custom dylibs.
> Simply re-run `make install` from this repository to re-scan and re-apply the Metal backend to all installed games.

---

## Installation & Usage

### 1. One-Click Install & Auto-Patch (All Games)

Clone the repository and run the universal installer:

```bash
git clone https://github.com/SteveShi/infinity-metal.git
cd infinity-metal
make install
```

> [!NOTE]
> The installer automatically scans `/Applications`, `~/Applications`, and Steam library folders for all installed Infinity Engine EE games.
>
> If you wish to patch a game in a custom location, specify `GAME_APP`:
> ```bash
> GAME_APP="/path/to/Game.app" make install
> ```

The installation script will:
1. Build `libInfinityMetal.dylib` as a Universal Binary (`arm64` + `x86_64`).
2. Deploy `libInfinityMetal.dylib` into every detected game app bundle.
3. Ad-hoc re-sign all game binaries with entitlements allowing local dynamic library injection.
4. Generate a one-click launcher `*.command` in each game's root directory.

### 2. Launching the Games

You can run any patched game with Metal acceleration via:
- **Finder**: Double-click the respective launcher in the game directory:
  - `Baldur's Gate (Metal).command`
  - `Baldur's Gate II (Metal).command`
  - `Icewind Dale (Metal).command`
  - `Planescape Torment (Metal).command`
- **Terminal**: Run `make test` to interactively select which game to launch.
- **GOG Galaxy / Steam**: In game settings, configure custom executable to launch the `(Metal).command` file.

### 3. Uninstallation

To restore all games to their stock state:

```bash
make uninstall
```

---

## Architecture & Technical Details

```
+-------------------------------------------------------------+
|    Infinity Engine: Enhanced Edition (BG1/BG2/IWD/PST)      |
|          Statically linked SDL2 & Infinity Engine EE        |
+-------------------------------------------------------------+
                              |
                     (OpenGL API Calls)
                              |
                              v
+-------------------------------------------------------------+
|              libInfinityMetal.dylib (Injected)              |
|  - fishhook: 71 GL symbol interceptions                     |
|  - Objective-C Swizzles: -[NSOpenGLContext flushBuffer/setView] |
|  - GLState: Shadow state tracker (matrix, blend, viewport)  |
|  - ShaderMap: MSL pipeline state caching & uST uniforms     |
|  - TextureManager: R8 / RGBA8 / DXT1 / DXT5 Metal textures  |
|  - MetalRenderer: Triple-buffered vertex stream & encoder   |
|  - MetalFX: Spatial upscaler pass (MTLFXSpatialScaler)      |
+-------------------------------------------------------------+
                              |
                       (Metal API)
                              v
+-------------------------------------------------------------+
|                      Apple Metal Driver                     |
|           CAMetalLayer -> 120Hz ProMotion Display           |
+-------------------------------------------------------------+
```

---

## Author & License

- **Author**: Steve Shi / 轩楝 (`zh-Hans`)
- **Bundle ID**: `com.steveshi.infinity-metal`
- **License**: Mozilla Public License 2.0 (MPL-2.0)

---

## Legal & Disclaimer

- *Baldur's Gate*, *Icewind Dale*, and *Planescape: Torment* are registered trademarks of Wizards of the Coast LLC, Hasbro Inc., Beamdog, and/or their respective owners.
- This project is an independent, non-commercial, third-party open-source compatibility and graphics translation layer. It is not affiliated with, endorsed by, or sponsored by Beamdog, Wizards of the Coast, Hasbro, GOG, or Valve Corporation.
- This repository contains no game assets, copyrighted art, audio, or proprietary binaries. A legally purchased copy of the original game is required to use this software.
