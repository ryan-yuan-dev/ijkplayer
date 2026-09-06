# AGENTS

## 远端仓库（记忆）
- 上游官网：`https://github.com/bilibili/ijkplayer.git`（只读同步，不直接 push）。
- 自有 fork：`https://github.com/ryan-yuan-dev/ijkplayer.git`（从官网 fork，本仓库代码一律提交并 push 到自有库）。
- 约定：`origin` = 自有库，`upstream` = 官网库。
- 工作分支：`ryan-dev`（现代化工作分支，按功能分批 commit 并 push；`master` 保持与上游对齐）。

## 项目
基于 FFmpeg 的播放器（Bilibili）。双端（Android / iOS）共享 `ijkmedia/` 核心，无包管理器、无单测、无 linter——一切以构建验证为准，不要尝试跑测试命令。FFmpeg 不在仓库内，由 init 脚本拉取上游 `n7.1`，ijk 定制通过 `patches-ffmpeg7` 补丁集打上。

## 现代化目标（source of truth）
1. 完整、正确地保留 ijkplayer 现有功能；
2. FFmpeg 升级到上游 `n7.1`，ijk 定制（ijk* protocol/demuxer、allformats/protocols 注册项等）通过 `patches-ffmpeg7` 补丁集打到上游源码上；
3. Android：`minSdk 24` / `targetSdk 36` / `compileSdk 36`，NDK r28（clang-only），ABI 仅 `arm64` + `x86_64`（armv5/armv7a/x86 裁剪）；
4. iOS：最低支持 iOS 13，真机 `arm64`，模拟器 `arm64-sim` / `x86_64-sim`（Apple Silicon 优先）；
5. Demo 工程现代化：Android 用 AGP 8.x + Gradle 8.x + AndroidX + Media3（`ijkplayer-exo`），iOS Xcode 工程升级到当前格式；
6. 构建主机：Windows 跑 Android 全链路（交叉编译 + Gradle + 模拟器），macOS 跑 Android + iOS 全部；所有 init/compile 脚本必须双平台可跑；
7. 跨平台交接：单平台会话完成的工作，必须为另一平台写交接文档到 `docs/handoff/`（打不上的 hunk、待验证项逐条记录，禁止静默丢弃）。

## 里程碑 / tag / CHANGELOG
- 阶段路线图与 tag 方案：`docs/version-plan.md`；各阶段执行记录：`docs/upgrade/`。
- tag 方案：`v0.9.0-alpha.1`（FFmpeg n7.1 基线）→ `v0.9.0-beta.1`（Android 全链路）→ `v0.9.0-rc.1`（iOS + CI 齐备）→ `v0.9.0`（双端验证通过）。
- 每个里程碑收口：更新根目录 `CHANGELOG.md` → `version.sh` 同步版本号 → 打 tag → push。历史变更记录在 `NEWS.md`（保持上游格式，不删）。

## FFmpeg 配置 — `config/module.sh`
- `config/module.sh` 永不提交；`init-config.sh:19` 若缺失则从 `module-lite.sh` 复制生成。
- 三档配置：`module-lite.sh`（默认最小集）、`module-lite-hevc.sh`、`module-default.sh`（全量）。
- 切换方式：`cd config && rm module.sh && ln -s module-lite.sh module.sh`（或其它档位），之后**必须**清理再重编：`cd android/contrib && sh compile-ffmpeg.sh clean`（或 `cd ios && ./compile-ffmpeg.sh clean`），否则编译选项残留。
- n7.1 注意：`--disable-avresample`、`--disable-ffserver` 已在三档中注释掉（FFmpeg 5.0+ 移除 libavresample、3.4+ 移除 ffserver）。

## 前置条件
- Android：NDK r28（`do-detect-env.sh` 强制校验 `28.*`）+ `ANDROID_HOME`（系统变量已配置）+ `ANDROID_NDK`；现代 JDK/Gradle（详见 `android/ijkplayer/`）。
- iOS 需 macOS + Xcode（当前稳定版即可）；`brew install git yasm`。
- Windows：Git Bash 环境跑 init/compile 脚本；`patch` 命令随 Git for Windows 提供。
- `init-*.sh` 克隆到 `extra/` 及分架构目录（`android/contrib/ffmpeg-*`、`ios/ffmpeg-*`），均被 gitignore，不要指望它们已存在。

## 构建顺序（必须串行）
```
./init-android.sh
cd android/contrib && ./compile-ffmpeg.sh all    # all|arm64|x86_64|clean|check
cd ../../android && ./compile-ijk.sh all         # all|arm64|x86_64|clean — 必须在 android/ 下执行
cd ijkplayer && ./gradlew assembleDebug
# iOS 等价（仅 macOS）：
./init-ios.sh                                     # 或 ./init-ios.sh [arm64|arm64-sim|x86_64-sim|all]
cd ios && ./compile-ffmpeg.sh all                 # 经 lipo 产出 build/universal/
# 随后打开 ios/IJKMediaDemo/IJKMediaDemo.xcodeproj
```
- `android/contrib/compile-ffmpeg.sh` 内部委托 `tools/do-compile-ffmpeg.sh`——必须在 `android/contrib/` 下执行。
- `android/compile-ijk.sh` 用 `ndk-build` 并行 `-j`，会做 `android-ndk-prof` 软链切换——勿删。Windows Git Bash 下无 `nproc`，脚本内以 `NUMBER_OF_PROCESSORS` 回退。
- `ios/compile-ffmpeg.sh` 委托 `tools/do-compile-ffmpeg.sh`——必须在 `ios/` 下执行。

## 工作目录约束
- `tools/pull-repo-base.sh` / `tools/pull-repo-ref.sh` 供 init 脚本调用；补丁在各 `ffmpeg-*` 目录内以 `patch -p1` 应用。
- iOS 相关脚本只能在 macOS 上验证；Windows 会话改动 iOS 构建链后必须写 `docs/handoff/` 交接。

## 目录结构
- `ijkmedia/ijkplayer/` — 共享核心（`ff_ffplay.c`、`ijkplayer.c`、`ff_ffpipeline.c`、`pipeline/`、`ijkavformat/`、`ijkavutil/`），Android 在 `android/` 子目录叠加平台代码，勿跨层改错位置。
- `ijkmedia/ijksdl/` — SDL 风格抽象（音视频输出、线程、锁、GLES2），双端共用。
- `ijkmedia/ijkj4a/` — Java4Android 胶水层。
- `android/patches-ffmpeg7/`、`ios/patches-ffmpeg7/` — 打在上游 FFmpeg n7.1 上的 ijk 定制补丁集。
- `android/ijkplayer/` — Gradle 根（`build.gradle` 定义 `versionCode`/`versionName`）；`settings.gradle` 声明模块（`ijkplayer-arm64`、`ijkplayer-x86_64`、`ijkplayer-java`、`ijkplayer-exo`、`ijkplayer-example`）。
- `ios/IJKMediaPlayer/` — ObjC 框架（`IJKFFMoviePlayerController.m` 由 `init-ios.sh:sync_ff_version` 同步 FFmpeg 版本）。
- `docs/` — `README.md`（索引）、`upgrade/`（阶段记录）、`knowledge_base/`（已验证结论，按需检索，索引见 docs/README.md）、`handoff/`（会话交接，用户手动发起）、`version-plan.md`（版本/tag 路线图）。
- `tools/` — 仓库初始化辅助脚本。

## 坑位
- 勿改生成文件 `ijkmedia/ijkplayer/ijkversion.h`（由 `Android.mk` 调 `version.sh` 生成）、`extra/`、`android/ffmpeg-*`、`ios/ffmpeg-*`、`android/build/`——均已 ignore。
- 版本唯一入口 `version.sh`，会批量改 `README.md`、`android/ijkplayer/build.gradle`、`gradle.properties`、`IJKMediaPlayer.xcodeproj/project.pbxproj`。
- 无测试/lint/typecheck——以构建验证为准。
- C 层向 FFmpeg n7.1 的迁移点用 `/* n7.1: ... */` 注释标记（见 `ff_ffplay.c`），保持该风格。
- `ijkmedia/ijkplayer/Android.mk` 中的 `-std=c99` 必须保留；旧 armeabi-v7a 的 `-mfloat-abi=soft` 分支已随 32 位 ABI 裁剪移除，不要再加回。
