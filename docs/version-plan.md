# 版本与 Tag 路线图

分支：`ryan-dev`。历史版本号沿用上游 `0.8.8`（`version.sh` 中 `VERSION_CODE=800800 / VERSION_NAME=0.8.8`）；现代化完成后进入 `0.9.0` 系列。

## Tag 方案

| Tag | 门槛 | 内容 |
|---|---|---|
| `v0.9.0-alpha.1` | M1 完成 | FFmpeg n7.1 基线：patches-ffmpeg7 补丁集（含 ijklas/ijklivehook 移植）、openssl 3.5、Android/iOS init 脚本切 n7.1；`compile-ffmpeg.sh` 双 ABI 构建通过 |
| `v0.9.0-beta.1` | M2+M3 完成 | Android 全链路：ndk-build 适配 NDK r28、Gradle 8.x/AGP 8.x/AndroidX/Media3、example 可安装可播放 |
| `v0.9.0-rc.1` | M4 完成 + `tools/verify-all.sh` 双平台通过 | iOS 全链路（iOS 13、arm64-sim、x86_64-sim）+ 本地一键验证脚本（Android 双 ABI + iOS 双 SDK），替代 M5 CI |
| `v0.9.0` | 双端验证 | 冒烟测试清单通过，`version.sh` bump 到 0.9.0 并同步 README/gradle/pbxproj |

## 收口流程（每个 tag）

1. 确认该里程碑全部验证项通过（构建为准：Android `tools/verify-all.sh android`，iOS 限 macOS 跑 `tools/verify-all.sh all`）；
2. 更新根目录 `CHANGELOG.md`（Keep a Changelog 格式）与 `NEWS.md`（上游格式追加）；
3. 若为 `v0.9.0` 终版：改 `version.sh` 的 `VERSION_NAME=0.9.0`、`VERSION_CODE=900000`，执行 `sh version.sh readme && sh version.sh gradle && sh version.sh xcode`；
4. `git tag <tag> && git push origin <tag>`。

## 后续版本预留

- `0.9.x`：修缺陷、补验证脚本；
- `1.0.0`：API 稳定承诺 + 发 Maven Central / CocoaPods（待定）。

## CI 说明（当前不接服务）

M5 原计划 GitHub Actions，暂不接入外部 CI 服务。验证门槛由 `tools/verify-all.sh`
（双平台一键全链路）承担；将来接入 CI 时，把脚本各 `step` 平移到
`.github/workflows/*.yml` 即可（Windows runner 跑 Android、macOS runner 跑 Android+iOS，
依赖安装见 `docs/knowledge_base/`）。
