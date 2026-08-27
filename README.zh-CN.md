# 异域镇魂曲：增强版 — Apple Metal 原生渲染后端 Mod

[**English Documentation**](README.md)

---

专为 macOS 平台上的 **《异域镇魂曲：增强版》（Planescape Torment: Enhanced Edition, PST:EE）** 定制开发的高性能、非侵入式 **Apple Metal** 原生渲染后端 Mod。

本项目通过动态库注入机制（`DYLD_INSERT_LIBRARIES`），彻底替换了 macOS 上已被弃用且存在性能瓶颈的 OpenGL 2.1 渲染管线，全面接入 Apple 原生 Metal 框架，带来 **120Hz ProMotion 高刷支持**、**MetalFX 空间超分辨率渲染**、极低 CPU 开销以及更清晰细腻的 Retina 视网膜屏显示效果。

---

## 核心特性

- **100% 纯 Metal 渲染转译**：完全取代系统 OpenGL，无任何系统级回退。对引擎所有的 Draw Calls、着色器程序、Uniform 矩阵与纹理上传进行原生拦截并转译为 Metal 命令流。
- **120Hz ProMotion 高刷与平滑帧同步**：深度接入 `CAMetalLayer` 与三重缓冲（Triple Buffering），完美支持 MacBook Pro / Studio Display 等 120Hz 高刷新率屏幕。
- **MetalFX 超分辨率（Spatial Upscaling）**：集成 macOS 13+ 的 `MTLFXSpatialScaler` 空间缩放管线与感知色彩处理，在 4K/5K 高分屏下提供极致清晰的图元表现。
- **像素级精准对齐原版引擎着色器**：
  - 逆向提取引擎 9 套完整 GLSL 着色器并在 Metal Shading Language 中精确复现（`vpDraw`/`fpDraw`、`fpTone`、`fpCatRom`、`vpYUV`/`fpYUV`、`fpYUVGRY`、`fpSprite`、`fpFONT`、`fpSELECT`、`fpSEAM`）。
  - 支持引擎独有的 2D `uST`（Scale & Translate）绝对坐标系变换。
  - 独家单纹理 Packed YUV 4:2:0 过场动画原画级无损解码。
  - 原生支持 NotoSans 动态 CJK 中文字符字形图集与经典位图字体。
- **非侵入式架构**：独立存放在 GitHub 工程目录中，不修改游戏原有资源文件，可一键安装与无痕卸载。

---

## 运行环境与版本兼容性

- **操作系统**：macOS 11.0 (Big Sur) 及以上（MetalFX 空间超分辨率特性需 macOS 13.0+）。
- **架构支持**：Universal Binary 通用二进制（原生支持 Apple Silicon M1/M2/M3/M4 系列及 Intel x86_64 芯片）。
- **游戏版本**：Planescape Torment: Enhanced Edition（GOG / Steam macOS 版本）。
  - **测试验证版本**：`v3.2.0.1` / `v3.1.3.0`（目前官方最新发布版本）。
  - **兼容性范围**：覆盖 PST:EE 3.x 全系列版本。
- **编译工具**：Xcode Command Line Tools（包含 `clang`、`metal`、`metallib`）。

> [!TIP]
> **官方游戏更新后的处理说明**：
> 若通过 GOG Galaxy 或 Steam 客户端更新了游戏，官方更新会重置 App 代码签名并清除非官方文件。
> 此时只需在本项目目录下重新执行一次 `make install` 即可一键恢复 Metal 渲染后端。

---

## 安装与使用说明

### 1. 一键编译与安装

克隆本仓库并执行安装：

```bash
git clone https://github.com/SteveShi/pstee-metal.git
cd pstee-metal
make install
```

> [!NOTE]
> 安装脚本会自动检索 macOS 默认的 GOG 与 Steam 游戏安装路径。
> 如果您的游戏存放在自定义目录，可显式指定 `GAME_APP` 参数：
> ```bash
> GAME_APP="/path/to/Planescape Torment - Enhanced Edition.app" make install
> ```

安装脚本将自动执行以下操作：
1. 编译生成双架构通用二进制动态库 `libPSTMetal.dylib`。
2. 将动态库拷贝部署至游戏 App 的 `Contents/MacOS/` 目录下。
3. 对游戏 App 进行 Ad-hoc 签名授权，开启本地动态库加载权限。
4. 在游戏根目录下创建双击即玩启动脚本：`Planescape Torment (Metal).command`。

### 2. 启动游戏

可通过以下任意一种方式以 Metal 渲染后端启动游戏：
- **访达双击**：双击游戏根目录下的 `Planescape Torment (Metal).command` 启动器。
- **终端启动**：在本项目根目录下运行 `make test`。
- **GOG Galaxy / Steam 客户端**：在游戏设置中将自定义可执行文件路径设置为 `Planescape Torment (Metal).command`。

### 3. 一键卸载与还原

如需恢复游戏至原版状态，只需执行：

```bash
make uninstall
```

---

## 架构与技术实现

```
+-------------------------------------------------------------+
|         Planescape Torment: Enhanced Edition (PST:EE)       |
|          静态链接 SDL2 与 Infinity Engine EE 引擎核心        |
+-------------------------------------------------------------+
                              |
                       (OpenGL API 调用)
                              |
                              v
+-------------------------------------------------------------+
|               libPSTMetal.dylib (动态注入层)                 |
|  - fishhook: 拦截 69 个核心 OpenGL 符号                      |
|  - ObjC Method Swizzling: 接管 -[NSOpenGLContext flush/setView] |
|  - GLState: 阴影状态机（矩阵、混合模式、视口剪裁）            |
|  - ShaderMap: MSL 管线状态缓存 (36 种状态) 与 uST 变换       |
|  - TextureManager: R8 / RGBA8 / DXT1 / DXT5 纹理映射         |
|  - MetalRenderer: 三重动态顶点缓冲流与帧提交管线              |
|  - MetalFX: 空间超分辨率着色 Pass                           |
+-------------------------------------------------------------+
                              |
                         (Metal API)
                              v
+-------------------------------------------------------------+
|                      Apple Metal 驱动层                     |
|           CAMetalLayer -> 120Hz ProMotion 视网膜屏幕输出     |
+-------------------------------------------------------------+
```

---

## 作者与许可

- **作者**：Steve Shi / 轩楝 (`zh-Hans`)
- **Bundle ID**：`com.steveshi.pstee-metal`
- **开源协议**：Mozilla Public License 2.0 (MPL-2.0)

---

## 法律与免责声明

- *《异域镇魂曲》（Planescape: Torment）* 及 *《异域镇魂曲：增强版》（Planescape: Torment: Enhanced Edition）* 为 Beamdog、Wizards of the Coast LLC、Hasbro Inc. 或其相应权利人的注册商标。
- 本项目为独立的非商业性第三方开源图形兼容层与技术研究成果，与 Beamdog、Wizards of the Coast、Hasbro、GOG 或 Valve Corporation 没有任何官方关联、赞助或背书关系。
- 本仓库不包含任何游戏原始受版权保护的美术、音频、剧本、专有资源或游戏本体二进制文件。用户须自行持有合法购买的正版游戏本体方可配合使用本 Mod。
