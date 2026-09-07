# M4 — iOS 全链路（2026-09-07，macOS 主机）

## 目标
在 macOS 上完成 iOS 全链路：FFmpeg n7.1 三架构（arm64 / arm64-sim / x86_64-sim）
编译、IJKMediaFramework / IJKMediaFrameworkWithSSL 双 framework、IJKMediaDemo 双 SDK
构建全部通过，为 `v0.9.0-rc.1` 收口。

## 环境
- macOS 26.6.2 / Xcode 26.4（iPhoneOS26.4.sdk）
- `brew install yasm`；gas-preprocessor.pl 从 FFmpeg 官方仓库下载到 `/opt/homebrew/bin/`
- 前置：`./init-ios.sh all`（n7.1 + patches-ffmpeg7 31 个补丁全部干净应用）

## 构建脚本现代化（本次新增，Windows 会话未覆盖）
`ios/compile-ffmpeg.sh` 与 `ios/tools/do-compile-ffmpeg.sh` 此前仍是旧 armv7/i386 时代，
本次对齐 `compile-openssl.sh` 的三架构模型：

1. **arch 列表**：`FF_ALL_ARCHS_IOS13_SDK="arm64 arm64-sim x86_64-sim"`（删除 armv7/armv7s/i386）。
2. **do-compile-ffmpeg.sh**：
   - 新增 `arm64-sim` / `x86_64-sim` 分支（iPhoneSimulator + `-mios-simulator-version-min=13.0`）；
   - 引入 `FF_XCRUN_ARCH`（clang `-arch` 用 `arm64`/`x86_64`，configure `--arch=` 同值），
     与构建名 `ffmpeg-arm64-sim` 解耦；
   - 删除 `--arch=$FF_ARCH` 的旧写法（`arm64-sim` 会传给 configure 报错）。
3. **lipo 拆分**：真机 arm64 与模拟器 arm64-sim 同为 arm64 CPU 类型，无法合成一个 fat 库。
   `compile-ffmpeg.sh` / `compile-openssl.sh` 的 `do_lipo_*` 现在：
   - 主 lipo 跳过 `*-sim` 架构 → `build/universal/`（真机 arm64）；
   - 新增 `do_lipo_*_sim` → `build/universal-sim/`（arm64-sim + x86_64-sim）。
4. **Xcode 工程**（`IJKMediaPlayer.xcodeproj` / `IJKMediaDemo.xcodeproj`）：
   - `IPHONEOS_DEPLOYMENT_TARGET` 7.0/8.0 → **13.0**（Xcode 26 已移除 libarclite，<12 无法链接）；
   - 新增 build setting `FF_TARGET_SUBDIR`（默认 `universal`，模拟器构建传 `universal-sim`），
     所有 `LIBRARY_SEARCH_PATHS`、ffmpeg group path、libssl/libcrypto 引用、`OTHER_LDFLAGS`
     的静态库路径统一走 `$(FF_TARGET_SUBDIR)`；
   - demo 的 `OTHER_LDFLAGS` 补 `-lssl -lcrypto`（WithSSL 框架的 tls_openssl.o 需要）。

## 源码迁移（iOS 侧 n7.1 API 差异，按 `/* n7.1: ... */` 风格处理）
- `IJKVideoToolBoxAsync.m` / `IJKVideoToolBoxSync.m`：
  - `av_packet_split_side_data()` 删除（n7.1 侧数据随包内联）→ 直接删除调用；
  - `ff_avc_parse_nal_units()` → `ff_nal_parse_units()`（n7.1 改名，`libavformat/nal.h`）；
  - `av_copy_packet()` 删除 → `av_packet_unref + av_packet_ref`；
  - `avcodec_decode_video2()` 删除 → `avcodec_send_packet + avcodec_receive_frame`。
- `IJKAudioKit.m`：`setActive:` 补 `return YES`（`-Werror=return-type`）。
- 补丁集：`0100-libavutil-application-h.patch` 补 `#include <stddef.h>`（Apple SDK 的
  `size_t` 不在 stdint.h 中，Android bionic 无此问题）；`0202-libavformat-Makefile.patch`
  的 HEADERS 增加 `nal.h`（VideoToolBox 依赖 `ff_nal_parse_units` 声明）。
  **两份补丁（android/ios）已逐字节一致。**

## 验证结果（全部 exit 0 / BUILD SUCCEEDED）
| 项 | 结果 |
|---|---|
| `compile-openssl.sh all` | universal（arm64）+ universal-sim（arm64-sim+x86_64-sim） |
| `compile-ffmpeg.sh all` | 同上，8 个库 × 2 套 |
| IJKMediaFramework（真机 arm64） | SUCCEEDED |
| IJKMediaFramework（模拟器 arm64+x86_64） | SUCCEEDED |
| IJKMediaFrameworkWithSSL（真机 arm64） | SUCCEEDED |
| IJKMediaFrameworkWithSSL（模拟器 x86_64） | SUCCEEDED |
| IJKMediaDemo（真机 arm64，免签名） | SUCCEEDED |
| IJKMediaDemo（模拟器 arm64+x86_64，免签名） | SUCCEEDED |

## 已知问题 / 待办
- [ ] `compile-ffmpeg.sh all` 在**后台无 TTY** 环境下 configure 会报
      `write error: Device not configured`（arm64-sim 首次 configure 失败）；
      前台串行执行正常。CI 用 `xcodebuild` 不受影响，但脚本级 CI 需注意。
- [ ] `IJKMediaDemo` 真机构建需开发者签名（本机用 `CODE_SIGNING_ALLOWED=NO` 验证编译）。
- [ ] `IJKMediaFrameworkWithSSL` 模拟器构建需显式传 `FF_TARGET_SUBDIR=universal-sim`；
      后续可考虑在 pbxproj 用 `SDK_NAME` 条件自动切换。
- [ ] `IJKMediaDemo` 的 `IJKDemoHistory.m` 有 NSKeyedArchiver 弃用 warning（非阻塞）。
- [ ] `IJKMediaFramework` 静态库产物含 `ijksdl_egl.o` 等无符号对象（libtool warning，非阻塞）。
