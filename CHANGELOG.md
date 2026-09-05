# Changelog

本项目自 `v0.9.0` 起采用 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式记录变更；
`0.8.8` 及之前的上游历史记录见 `NEWS.md`（保持原格式，不再追加）。

版本节奏与 tag 方案见 `docs/version-plan.md`。

## [Unreleased]

### 现代化（分支 `ryan-dev`，进行中）

#### 已完成
- **FFmpeg**：从 Bilibili fork `ff4.0--ijk0.8.8--20210426--001` 切换到上游 `n7.1`（`init-android.sh`），ijk 定制改为 `patches-ffmpeg7` 补丁集承载。
- **ijkmedia C 层**：迁移到 FFmpeg n7.1 API（send/receive 解码、`AVChannelLayout`/`ch_layout`、const `AVCodec`）；`ijklas.c`/`ijklivehook.c` 因依赖 `FFInputFormat` 内部结构移出编译，改由补丁集承载。
- **Android 编译脚本**：适配 NDK r28（clang-only），ABI 裁剪为 `arm64` + `x86_64`，链接加 16K page 对齐（`-Wl,-z,max-page-size=16384`）。
- **文档**：`AGENTS.md` 按新目标重写；新增 `docs/`（upgrade / knowledge_base / handoff / version-plan）与 `CHANGELOG.md`。

#### 进行中
- `patches-ffmpeg7` 补丁集生成与 n7.1 移植（M1）。
- openssl 1.0.2q → 3.5 LTS（M1）。

#### 计划
- Android：ndk-build 适配 NDK r28（M2）；Gradle 8.x / AGP 8.x / AndroidX / Media3（M3）。
- iOS：n7.1 + iOS 13 + arm64-sim（M4）。
- CI：GitHub Actions（Windows/macos 构建验证，M5）。
