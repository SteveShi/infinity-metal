# 无限引擎：增强版 — Apple Metal 原生渲染后端 Mod

[**English Documentation**](README.md)

---

专为 macOS 平台上的 **Infinity Engine 增强版（EE）全系列游戏** 定制开发的高性能、非侵入式 **Apple Metal** 原生渲染后端 Mod。

本项目通过动态库注入机制（`DYLD_INSERT_LIBRARIES`），彻底替换了 macOS 上已被弃用且存在性能瓶颈的 OpenGL 2.1 渲染管线，全面接入 Apple 原生 Metal 框架，带来 **120Hz ProMotion 高刷支持**、**MetalFX 空间超分辨率渲染**、极低 CPU 开销以及更清晰细腻的 Retina 视网膜屏显示效果。

---

## 🎮 支持游戏列表

单一 Universal Binary 动态库（`libInfinityMetal.dylib`）可自动检测、安装并同时支持全部 4 款 Beamdog Infinity Engine EE 作品：

| 游戏名称 | 测试版本 | 默认 macOS 目录 |
| :--- | :--- | :--- |
| **《博德之门：增强版》**（BG1:EE / 龙矛围城） | v2.6.6 / v2.7.3 | `/Applications/Baldur's Gate Enhanced Edition/` |
| **《博德之门 II：增强版》**（BG2:EE） | v2.6.6 / v2.7.3 | `/Applications/Baldur's Gate II Enhanced Edition/` |
| **《冰风谷：增强版》**（IWD:EE） | v2.6.6 | `/Applications/Icewind Dale Enhanced Edition/` |
| **《异域镇魂曲：增强版》**（PST:EE） | v3.1.3 / v3.2.1 | `/Applications/Planescape Torment - Enhanced Edition/` |

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
- **像素级鼠标交互对齐**：物理视网膜分辨率与 AppKit 鼠标判定精准 1:1 对齐，按键即点即响应。
- **非侵入式架构**：独立存放在 GitHub 工程目录中，不修改游戏原有资源文件，可一键全游戏安装与无痕卸载。

---

## 运行环境与版本兼容性

- **操作系统**：macOS 11.0 (Big Sur) 及以上（MetalFX 空间超分辨率特性需 macOS 13.0+）。
- **架构支持**：Universal Binary 通用二进制（原生支持 Apple Silicon M1/M2/M3/M4 系列及 Intel x86_64 芯片）。
- **游戏版本**：Beamdog Infinity Engine EE 增强版系列游戏（GOG / Steam macOS 版本）。
- **编译工具**：Xcode Command Line Tools（包含 `clang`、`metal`、`metallib`）。

> [!TIP]
> **官方游戏更新后的处理说明**：
> 若通过 GOG Galaxy 或 Steam 客户端更新了任意一款游戏，官方更新会重置该 App 代码签名并清除非官方文件。
> 此时只需在本项目目录下重新执行一次 `make install` 即可自动重新扫描并为所有游戏一键恢复 Metal 渲染后端。

---

## 安装与使用说明

### 1. 一键全自动扫描与安装（所有游戏）

克隆本仓库并执行安装：

```bash
git clone https://github.com/SteveShi/infinity-metal.git
cd infinity-metal
make install
```

> [!NOTE]
> 安装脚本会自动扫描 `/Applications`、`~/Applications` 以及 Steam 默认库路径下安装的所有 Infinity Engine EE 游戏。
>
> 如需为存放在自定义目录的特定游戏打补丁，可显式指定 `GAME_APP` 参数：
> ```bash
> GAME_APP="/path/to/Game.app" make install
> ```

安装脚本将自动执行以下操作：
1. 编译生成双架构通用二进制动态库 `libInfinityMetal.dylib`。
2. 将动态库拷贝部署至每一个检测到的游戏 App 内。
3. 对每个游戏 App 进行 Ad-hoc 签名授权，开启本地动态库加载权限。
4. 在每个游戏的根目录下创建各自专属的双击即玩启动脚本（如 `Baldur's Gate (Metal).command`）。

### 2. 启动游戏

可通过以下任意一种方式以 Metal 渲染后端启动游戏：
- **访达双击**：双击任意游戏根目录下的 `*(Metal).command` 启动器：
  - `Baldur's Gate (Metal).command`
  - `Baldur's Gate II (Metal).command`
  - `Icewind Dale (Metal).command`
  - `Planescape Torment (Metal).command`
- **终端启动**：在本项目根目录下运行 `make test`，交互式选择要运行的游戏。
- **GOG Galaxy / Steam 客户端**：在游戏设置中将自定义可执行文件路径设置为对应的 `(Metal).command`。

### 3. 一键卸载与还原

如需恢复所有游戏至原版状态，只需执行：

```bash
make uninstall
```

---

## 架构与技术实现

```
+-------------------------------------------------------------+
|    Infinity Engine: Enhanced Edition (BG1/BG2/IWD/PST)      |
|          静态链接 SDL2 与 Infinity Engine EE 引擎核心        |
+-------------------------------------------------------------+
                              |
                       (OpenGL API 调用)
                              |
                              v
+-------------------------------------------------------------+
|             libInfinityMetal.dylib (动态注入层)             |
|  - fishhook: 拦截 71 个核心 OpenGL 符号                      |
|  - ObjC Method Swizzling: 接管 -[NSOpenGLContext flush/setView] |
|  - GLState: 阴影状态机（矩阵、混合模式、视口剪裁）            |
|  - ShaderMap: MSL 管线状态缓存 (36 种状态) 与 uST 变换       |
|  - TextureManager: R8 / RGBA8 / DXT1 / DXT5 纹理映射         |
|  - MetalRenderer: 三重动态顶点缓冲流与帧提交管线              |
|  - MetalFX: 空间超分辨率着色 Pass (MTLFXSpatialScaler)      |
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
- **Bundle ID**：`com.steveshi.infinity-metal`
- **开源协议**：Mozilla Public License 2.0 (MPL-2.0)

---

## 法律与免责声明

- *《博德之门》（Baldur's Gate）*、*《冰风谷》（Icewind Dale）* 及 *《异域镇魂曲》（Planescape: Torment）* 为 Wizards of the Coast LLC、Hasbro Inc.、Beamdog 或其相应权利人的注册商标。
- 本项目为独立的非商业性第三方开源图形兼容层与技术研究成果，与 Beamdog、Wizards of the Coast、Hasbro、GOG 或 Valve Corporation 没有任何官方关联、赞助或背书关系。
- 本仓库不包含任何游戏原始受版权保护的美术、音频、剧本、专有资源或游戏本体二进制文件。用户须自行持有合法购买的正版游戏本体方可配合使用本 Mod。
