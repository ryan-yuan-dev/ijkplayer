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
- **iOS 全链路**（M4，macOS）：`compile-ffmpeg.sh`/`do-compile-ffmpeg.sh` 现代化为三架构（arm64 / arm64-sim / x86_64-sim），lipo 拆分 `universal/`（真机）与 `universal-sim/`（模拟器）；Xcode 工程 deployment target 升到 iOS 13，新增 `FF_TARGET_SUBDIR` build setting 统一双 SDK 库路径；VideoToolBox 管线迁移 n7.1 API（`ff_nal_parse_units`、send/receive 解码、`av_packet_ref`）；`IJKMediaFramework`/`IJKMediaFrameworkWithSSL`/`IJKMediaDemo` 真机+模拟器全部构建通过。
- **验证脚本**（替代 M5 CI）：新增 `tools/verify-all.sh` 双平台一键全链路验证（Android 双 ABI + iOS 双 SDK）；`init-android.sh`/`init-ios.sh` 补丁应用改为先 `git reset --hard` + `git clean` 保证幂等；`compile-ijk.sh` 自动推导 NDK 并补齐 `libijkffmpeg.so` 安装。
- **Android 设备实机冒烟**（真机 SDK 36 / arm64）：修复 edge-to-edge 下 toolbar 被状态栏遮挡（system bar inset）；ijklas `video_cache_ptr`/`audio_cache_ptr` 选项改 `AV_OPT_TYPE_STRING` 以兼容 FFmpeg 7 的 int64 double 校验（高地址 tagged 指针不再越界，las manifest 可走通至真实拉流阶段）；example demo 修 support 残留引用、Sample 列表长按复制 + 副标题省略、播放错误文案友好化；bipbop HLS 端到端播放验证通过。

#### 待办（移交 macOS 会话，见 docs/handoff/2026-09-06-m4-ios-m5-ci.md）
- M4：iOS 全链路验证（iOS 13 / arm64 / arm64-sim / x86_64-sim）。
- M5：GitHub Actions CI（Windows 验证 Android，macOS 验证 Android + iOS）。

#### Tag 计划（docs/version-plan.md）
- `v0.9.0-alpha.1`：FFmpeg n7.1 基线（M1，已完成）。
- `v0.9.0-beta.1`：Android 全链路（M2+M3，已完成）。
- `v0.9.0-rc.1`：iOS 全链路 + `tools/verify-all.sh` 双平台通过（M4，已完成）。
- `v0.9.0-rc.2`：rc.1 修复 + Android 真机冒烟通过（ijklas FFmpeg 7 cache_ptr 修复、demo AndroidX/edge-to-edge、bipbop 实播验证）。

#### 计划
- Android：ndk-build 适配 NDK r28（M2）；Gradle 8.x / AGP 8.x / AndroidX / Media3（M3）。
- iOS：n7.1 + iOS 13 + arm64-sim（M4）。
- CI：GitHub Actions（Windows/macos 构建验证，M5）。
- 终版 `v0.9.0`：iOS 真机冒烟验证通过后 `version.sh` bump 到 0.9.0。
