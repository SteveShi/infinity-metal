# Planescape Torment: Enhanced Edition — Metal Rendering Backend Mod

[**中文文档 (Simplified Chinese)**](README.zh-CN.md)

---

A high-performance, non-invasive **Apple Metal** rendering backend mod for **Planescape Torment: Enhanced Edition (PST:EE)** on macOS.

This mod completely replaces the legacy and deprecated macOS OpenGL 2.1 fixed/programmable pipeline with a native Apple Metal implementation via dynamic library injection (`DYLD_INSERT_LIBRARIES`), unlocking **120Hz ProMotion high refresh rates**, **MetalFX Spatial Upscaling**, reduced CPU overhead, and flawless Retina display rendering on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## Key Features

- **100% Native Apple Metal Translation**: Zero OpenGL system fallbacks. Intercepts all draw calls, shader programs, uniform bindings, and texture uploads directly to the Metal command queue.
- **120Hz ProMotion VSync Support**: Uses `CAMetalLayer` with `displaySyncEnabled` and triple-buffered frame pacing to support 120Hz variable refresh rate displays.
- **MetalFX Spatial Upscaling**: Integrated Apple MetalFX Spatial Scaler pass (`MTLFXSpatialScaler`) with perceptual color processing for crisp rendering on 4K/5K Retina displays.
- **Pixel-Perfect Shader & Font Reproduction**:
  - Implements all 9 PST:EE engine shaders directly in Metal Shading Language (`vpDraw`/`fpDraw`, `fpTone`, `fpCatRom`, `vpYUV`/`fpYUV`, `fpYUVGRY`, `fpSprite`, `fpFONT`, `fpSELECT`, `fpSEAM`).
  - Supports 2D Scale & Translate (`uST`) projection mapping.
  - Native single-texture packed YUV 4:2:0 video cutscene playback without color degradation.
  - Dynamic FreeType/NotoSans CJK font glyph cache and legacy BAM font rendering.
- **Non-Invasive Architecture**: The original game files are untouched. The mod resides in its own repository and is injected cleanly at launch time.

---

## Requirements & Compatibility

- **macOS**: 11.0 (Big Sur) or higher (macOS 13.0+ required for MetalFX Spatial Upscaler).
- **Architecture**: Universal Binary (`arm64` Apple Silicon + `x86_64` Intel).
- **Game Version**: Planescape Torment: Enhanced Edition (GOG / Steam macOS release).
  - **Tested & Verified Version**: `v3.2.0.1` / `v3.1.3.0` (Latest release).
  - **Compatibility**: All PST:EE v3.x series.
- **Build Tools**: Xcode Command Line Tools (`clang`, `metal`, `metallib`).

> [!TIP]
> **After Official Game Updates**:
> If Steam or GOG Galaxy updates the game, the official update will overwrite the game bundle signature and remove custom dylibs.
> Simply re-run `make install` from this repository to re-apply the Metal backend.

---

## Installation & Usage

### 1. One-Click Install & Patch

Clone the repository and run the installer:

```bash
git clone https://github.com/SteveShi/pstee-metal.git
cd pstee-metal
make install
```

> [!NOTE]
> The installer automatically discovers your game app across standard GOG and Steam macOS locations.
> If your game is located in a custom directory, specify `GAME_APP` explicitly:
> ```bash
> GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" make install
> ```

The installation script will:
1. Build `libPSTMetal.dylib` as a Universal Binary (`arm64` + `x86_64`).
2. Deploy `libPSTMetal.dylib` into the game app bundle.
3. Ad-hoc re-sign the game binary with entitlements allowing local dynamic library injection.
4. Generate a one-click launcher `Planescape Torment (Metal).command` in your game directory.

### 2. Launching the Game

You can run the game with Metal acceleration via:
- **Finder**: Double-click `Planescape Torment (Metal).command` in the game directory.
- **Terminal**: Run `make test` from this repository.
- **GOG Galaxy / Steam**: In game settings, configure custom executable to launch `Planescape Torment (Metal).command`.

### 3. Uninstallation

To restore the game to its stock state:

```bash
make uninstall
```

---

## Architecture & Technical Details

```
+-------------------------------------------------------------+
|         Planescape Torment: Enhanced Edition (PST:EE)       |
|          Statically linked SDL2 & Infinity Engine EE        |
+-------------------------------------------------------------+
                              |
                     (OpenGL API Calls)
                              |
                              v
+-------------------------------------------------------------+
|               libPSTMetal.dylib (Injected)                  |
|  - fishhook: 69 GL symbol interceptions                     |
|  - Objective-C Swizzles: -[NSOpenGLContext flushBuffer/setView] |
|  - GLState: Shadow state tracker (matrix, blend, viewport)  |
|  - ShaderMap: MSL pipeline state caching & uST uniforms     |
|  - TextureManager: R8 / RGBA8 / DXT1 / DXT5 Metal textures  |
|  - MetalRenderer: Triple-buffered vertex stream & encoder   |
|  - MetalFX: Spatial upscaler pass                           |
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
- **Bundle ID**: `com.steveshi.pstee-metal`
- **License**: Mozilla Public License 2.0 (MPL-2.0)

---

## Legal & Disclaimer

- *Planescape: Torment* and *Planescape: Torment: Enhanced Edition* are registered trademarks of Beamdog, Wizards of the Coast LLC, Hasbro Inc., and/or their respective owners.
- This project is an independent, non-commercial, third-party open-source compatibility and graphics translation layer. It is not affiliated with, endorsed by, or sponsored by Beamdog, Wizards of the Coast, Hasbro, GOG, or Valve Corporation.
- This repository contains no game assets, copyrighted art, audio, or proprietary binaries. A legally purchased copy of the original game is required to use this software.
