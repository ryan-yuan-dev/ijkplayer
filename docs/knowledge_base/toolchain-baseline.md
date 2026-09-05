# Toolchain 基线（已验证）

## Android（双主机通用）
- 依赖环境变量：`ANDROID_HOME`（SDK 根目录，系统变量已配置）+ `ANDROID_NDK`（指向 `ndk/28.*`）。
- NDK：`ndk/28.2.13676358`（`source.properties` 待构建时二次确认版本串）。
- platform：`platforms/android-36` 存在；`minSdk 24 / targetSdk 36 / compileSdk 36`。
- build-tools：`36.1.0`（`36.0.0` 亦存在，以 `36.1.0` 为准）。
- ABI 决策（2026-09-06 确认）：仅 `arm64` + `x86_64`；armv5/armv7a/x86 模块与脚本分支裁剪。
- FFmpeg 基线：上游 `https://github.com/FFmpeg/FFmpeg` 的 `n7.1` 分支最新点 + `android/patches-ffmpeg7/` 补丁集。
- OpenSSL 基线：`3.5 LTS`（tag 以 `git ls-remote` 可达为准）。

## iOS（仅 macOS 主机）
- 最低部署版本：**iOS 13.0**（2026-09-06 用户确认，覆盖旧记录的 15.0）。
- 架构：真机 arm64 + 模拟器 arm64-sim（Apple Silicon）；x86_64-sim 可选；armv7/armv7s/i386 移除。

## 构建约束
- `android/contrib` 下跑 `compile-ffmpeg.sh`；`android/` 下跑 `compile-ijk.sh`；`ios/` 下跑 `compile-ffmpeg.sh`。
- 构建主机：Windows（Git Bash）可跑 Android 全链路；iOS 仅 macOS。
- Windows Git Bash 无 `nproc`/`sysctl`，并行度探测需回退 `NUMBER_OF_PROCESSORS`。
