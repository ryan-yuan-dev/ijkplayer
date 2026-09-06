# Changelog

本项目自 `v0.9.0` 起采用 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式记录变更；
`0.8.8` 及之前的上游历史记录见 `NEWS.md`（保持原格式，不再追加）。

版本节奏与 tag 方案见 `docs/version-plan.md`。

## [Unreleased]

### 现代化（分支 `ryan-dev`，进行中）

#### 已完成
- **FFmpeg**：从 Bilibili fork `ff4.0--ijk0.8.8--20210426--001` 切换到上游 `n7.1`（`init-android.sh`），ijk 定制改为 `patches-ffmpeg7` 补丁集承载。
- **ijkmedia C 层**：迁移到 FFmpeg n7.1 API（send/receive 解码、`AVChannelLayout`/`ch_layout`、const `AVCodec`）；`ijklas.c`/`ijklivehook.c` 因依赖 `FFInputFormat` 内部结构移出编译，改由补丁集承载。
- **Android 编译脚本**：适配 NDK r28（clang-only），ABI 裁剪为 `arm64` + `x86_64`，链接加 16K page 对齐（`-Wl,-z,max-page-size=16384`）、`-Wl,-Bsymbolic` 与递归对象收集；openssl 升级到 3.5 LTS。
- **Android FFmpeg 构建验证**（Windows）：openssl-3.5.8 与 `libijkffmpeg.so` 双 ABI（arm64/x86_64）编译通过（M1）。
- **Android native 层 CMake 化**（M2/M2.5）：ndk-build 替换为 CMake+Ninja（NDK toolchain 文件），源码清单迁入 `ijkmedia/*/CMakeLists.txt`；`compile-ijk.sh` 双 ABI 验证通过。
- **Gradle 现代化**（M3）：Gradle 8.11.1 + AGP 8.10.1 + AndroidX，compileSdk/targetSdk 36、minSdk 24，模块 namespace 化，`all32/all64` flavor 移除。
- **ijkplayer-exo → androidx.media3**（M3）：重写 `IjkExoMediaPlayer`（r1.5 时代的 DemoPlayer/RendererBuilder 全部移除，HLS/DASH/SS 由 DefaultMediaSourceFactory 承载）。
- **example AndroidX 迁移**（M3）：22 个源文件 + manifest（exported），`assembleDebug` 通过，APK 含双 ABI 全部 native 库。
- **文档**：`AGENTS.md` 按新目标重写；新增 `docs/`（upgrade / knowledge_base / handoff / version-plan）与 `CHANGELOG.md`。

#### 待办（移交 macOS 会话，见 docs/handoff/2026-09-06-m4-ios-m5-ci.md）
- M4：iOS 全链路验证（iOS 13 / arm64 / arm64-sim / x86_64-sim）。
- M5：GitHub Actions CI（Windows 验证 Android，macOS 验证 Android + iOS）。

#### Tag 计划（docs/version-plan.md）
- `v0.9.0-alpha.1`：FFmpeg n7.1 基线（M1，已完成）。
- `v0.9.0-beta.1`：Android 全链路（M2+M3，已完成）。

#### 计划
- Android：ndk-build 适配 NDK r28（M2）；Gradle 8.x / AGP 8.x / AndroidX / Media3（M3）。
- iOS：n7.1 + iOS 13 + arm64-sim（M4）。
- CI：GitHub Actions（Windows/macos 构建验证，M5）。
