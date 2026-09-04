# AGENTS

## 远端仓库（记忆）
- 上游官网：`https://github.com/bilibili/ijkplayer.git`（只读同步，不直接 push）。
- 自有 fork：`https://github.com/ryan-yuan-dev/ijkplayer.git`（从官网 fork，本仓库代码一律提交并 push 到自有库）。
- 约定：`origin` = 自有库，`upstream` = 官网库。

## 项目
基于 FFmpeg 的播放器（Bilibili）。双端（Android / iOS）共享 `ijkmedia/` 核心，无包管理器、无测试、无 linter。FFmpeg 不在仓库内，由初始化脚本拉取，当前 pin `ff4.0--ijk0.8.8--20210426--001` 来自 `Bilibili/FFmpeg`（见 `init-android.sh:22`、`init-ios.sh:22`）。

## 前置条件
- iOS 需 macOS + Xcode；Android 需 NDK r10e + Android Studio 2.x + Gradle 2.14.1 + `compileSdkVersion` 25（`android/ijkplayer/build.gradle:24`），工具链陈旧——现代 JDK/Gradle 会失败。
- `brew install git yasm`
- 执行任何 `android/*` 脚本前必须 `export ANDROID_SDK=<path> ANDROID_NDK=<path>`，否则 `compile-ijk.sh:19` 直接退出。
- `init-*.sh` 克隆到 `extra/` 及分架构目录（`android/contrib/ffmpeg-*`、`ios/ffmpeg-*`），均被 gitignore，不要指望它们已存在。

## FFmpeg 配置 — `config/module.sh`
- `config/module.sh` 永不提交；`init-config.sh:19` 若缺失则从 `module-lite.sh` 复制生成。
- 三档配置：`module-lite.sh`（默认最小集）、`module-lite-hevc.sh`、`module-default.sh`（全量）。
- 切换方式：`cd config && rm module.sh && ln -s module-lite.sh module.sh`（或其它档位），之后**必须**清理再重编：`cd android/contrib && sh compile-ffmpeg.sh clean`（或 `cd ios && ./compile-ffmpeg.sh clean`），否则编译选项残留。

## 构建顺序（必须串行）
```
./init-android.sh        # 或 ./init-ios.sh [armv7|arm64|i386|x86_64|all]
cd android/contrib && ./compile-ffmpeg.sh all   # all|all32|armv7a|arm64|x86|x86_64|clean|check
cd .. && ./compile-ijk.sh all                   # all|all32|armv5|armv7a|arm64|x86|x86_64|clean — 必须在 android/ 下执行
# iOS 等价：
cd ios && ./compile-ffmpeg.sh all               # all|armv7|arm64|i386|x86_64|lipo|clean|check — 经 lipo 产出 build/universal/
# 随后打开 ios/IJKMediaDemo/IJKMediaDemo.xcodeproj
```
- CI（`/.travis.yml:11`）仅执行 `cd android/ijkplayer && ./gradlew assemble`，无单测。
- `android/compile-ijk.sh` 用 `ndk-build` 并行 `-j$(nproc)` / `sysctl -n machdep.cpu.thread_count`，会做 `android-ndk-prof` 软链切换——勿删。

## 工作目录约束
- `android/contrib/compile-ffmpeg.sh` 内部委托 `tools/do-compile-ffmpeg.sh`——必须在 `android/contrib/` 下执行。
- `android/compile-ijk.sh` 会 `cd` 到 `ijkplayer/ijkplayer-<abi>/src/main/jni`——必须在 `android/` 下执行。
- `ios/compile-ffmpeg.sh` 委托 `tools/do-compile-ffmpeg.sh`——必须在 `ios/` 下执行。

## 目录结构
- `ijkmedia/ijkplayer/` — 共享核心（`ff_ffplay.c`、`ijkplayer.c`、`ff_ffpipeline.c`、`pipeline/`、`ijkavformat/`、`ijkavutil/`），Android 在 `android/` 子目录叠加平台代码，勿跨层改错位置。
- `ijkmedia/ijksdl/` — SDL 风格抽象（音视频输出、线程、锁、GLES2），双端共用。
- `ijkmedia/ijkj4a/` — Java4Android 胶水层。
- `android/ijkplayer/` — Gradle 根（`build.gradle` 定义 `versionCode`/`versionName`）；`settings.gradle:1` 声明模块（`ijkplayer-armv5/armv7a/arm64/x86/x86_64`、`ijkplayer-java`、`ijkplayer-exo`、`ijkplayer-example`）。
- `ios/IJKMediaPlayer/` — ObjC 框架（`IJKFFMoviePlayerController.m` 由 `init-ios.sh:sync_ff_version` 同步 FFmpeg 版本）。
- `tools/` — `pull-repo-base.sh` / `pull-repo-ref.sh` 供初始化脚本调用。

## 坑位
- 勿改生成文件 `ijkmedia/ijkplayer/ijkversion.h`（由 `ijkmedia/ijkplayer/Android.mk:85` 生成）、`extra/`、`android/ffmpeg-*`、`ios/ffmpeg-*`、`android/build/`——均已 ignore。
- 版本唯一入口 `version.sh`，会批量改 `README.md`、`android/ijkplayer/build.gradle`、`gradle.properties`、`IJKMediaPlayer.xcodeproj/project.pbxproj`。
- 无测试/lint/typecheck——以构建验证为准，不要尝试跑测试命令。
- `armeabi-v7a` 的 `-mfloat-abi=soft` 与 `-std=c99` 定义在 `ijkmedia/ijkplayer/Android.mk:27`，改 C  flags 时需保留。
