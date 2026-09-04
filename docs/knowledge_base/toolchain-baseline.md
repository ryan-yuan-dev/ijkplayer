# Toolchain 基线（已验证）

- `ANDROID_HOME=/Volumes/MacOS/Users/Ryan/workspace/Ansjer/environments/Android/sdk`（注意 `Ansjer` 拼写）。
- NDK：`ndk/28.2.13676358`（`source.properties` 待构建时二次确认版本串）。
- platform：`platforms/android-36` 存在；`minSdk 24 / targetSdk 36 / compileSdk 36`。
- build-tools：`36.1.0`（`36.0.0` 亦存在，以 `36.1.0` 为准）。
- FFmpeg 基线：上游 `https://github.com/FFmpeg/FFmpeg` 的 `n7.1` 分支最新点 + `android/patches-ffmpeg7/` 补丁集。
- OpenSSL 基线：`3.5 LTS`（tag 以 `git ls-remote` 可达为准）。
- iOS：最低 15.0；架构真机 arm64 + 模拟器 arm64（x86_64-sim 可选）。
- 构建约束：`android/contrib` 下跑 `compile-ffmpeg.sh`；`android/` 下跑 `compile-ijk.sh`；`ios/` 下跑 `compile-ffmpeg.sh`。
