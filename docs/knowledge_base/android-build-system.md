# Android 构建体系（CMake native + Gradle，已验证）

> 2026-09-06 M2/M3 完成 ndk-build → CMake、Gradle 2.14/AGP 2.1 → Gradle 8.11.1/AGP 8.10.1 的迁移。
> 本篇讲结构与操作；Windows 环境细节见 `windows-build-env.md`，版本基线见 `toolchain-baseline.md`。

## 构建顺序速查（全链路）

| 步骤 | 命令 | 成功标志 |
|---|---|---|
| 1. init | `./init-android.sh` | `android/contrib/ffmpeg-{arm64,x86_64}/` 就绪、补丁干净应用 |
| 2. openssl | `cd android/contrib && sh compile-openssl.sh all` | `build/openssl-<abi>/output/lib/lib{ssl,crypto}.a` |
| 3. ffmpeg | `sh compile-ffmpeg.sh all` | `build/ffmpeg-<abi>/output/libijkffmpeg.so` |
| 4. ijk native | `cd ../../android && sh compile-ijk.sh all` | `ijkplayer/ijkplayer-<abi>/src/main/libs/<abi>/lib{ijkplayer,ijksdl}.so` |
| 5. gradle | `cd ijkplayer && ./gradlew assembleDebug`（JDK 17+） | `ijkplayer-example/build/outputs/apk/debug/ijkplayer-example-debug.apk` |

- APK 校验点：含 `lib/{arm64-v8a,x86_64}/lib{ijkplayer,ijksdl,ijkffmpeg}.so` 共 6 个；
  `unzip -l <apk> | grep lib/`。
- `compile-ijk.sh` 参数：`arm64 | x86_64 | all | clean`（32 位 ABI 已裁剪）。

## Native 层（CMake）

- `compile-ijk.sh` = CMake 驱动：`cmake -G Ninja` + NDK toolchain 文件
  （`ANDROID_STL=c++_static`、`ANDROID_PLATFORM=android-24`），build 目录
  `src/main/obj/cmake`（gitignore），产物 find 后拷入 `src/main/libs/<abi>/`。
- **源码清单 source of truth**：`ijkmedia/{ijkplayer,ijksdl,ijkj4a}/CMakeLists.txt`
  （与未来 iOS CMake 共享）。`ff_ffplay.c` 等改文件名/加文件时同步这三处。
- **vendored 库**：`ijkmedia/{ijkyuv,ijksoundtouch}` 是 gitignore 的 Bilibili fork
  （init 脚本克隆，重克隆会清掉目录内新文件），故其 CMake targets 定义在模块级
  `android/ijkplayer/ijkplayer-arm64|ijkplayer-x86_64/src/main/jni/CMakeLists.txt`
  里，**不要**把 CMakeLists 写进这两个目录。
- `jni/ijkmedia` 目录链接（→仓库根 ijkmedia）在 Windows 由
  `fix_win_jni_links()` 建 junction 兜底。
- 顶层 CMakeLists 里 `IJK_FFMPEG_INCLUDE_PATH` 指向 contrib 的 ffmpeg 输出 include，
  ijksdl/ijkplayer 显式依赖（另有 `include/libffmpeg/config.h` 被 ijkplayer/config.h 引用）。
- 原 ndk-build 文件（jni/Android.mk、Application.mk、ffmpeg/、ijkmedia 库级 Android.mk）
  已删除；vendored 目录内的 Android.mk 保留未动（fork 领地）。

## Gradle 层

- 版本对：**AGP 8.10.1 + Gradle 8.11.1 + JDK 17**（`JAVA_HOME` 指向 JDK 17+；
  Android Studio 自带 jbr 21 亦可用）。
- 模块（`android/ijkplayer/settings.gradle`）：`ijkplayer-arm64`、`ijkplayer-x86_64`
  （纯 jniLibs 壳，`jniLibs.srcDirs 'src/main/libs'`）、`ijkplayer-java`（纯 Java API）、
  `ijkplayer-exo`（media3 wrapper）、`ijkplayer-example`。
- AGP 8 规则：`namespace` 写在各模块 build.gradle（manifest 不得再有 `package=`）；
  intent-filter 的 activity 需显式 `android:exported`。
- 仓库源：`settings.gradle` 里 google + mavenCentral，另配 Aliyun 镜像兜底
  （本机直连 mavenCentral TLS 间歇失败）；`FAIL_ON_PROJECT_REPOS` 已启用，
  不要在模块里加 repositories。
- `ijkplayer-exo` 依赖 `androidx.media3:*:1.8.0`；`IjkExoMediaPlayer` 是
  `IMediaPlayer` facade（media3 ExoPlayer 直连），改播放器行为时两套
  （IjkMediaPlayer native / IjkExoMediaPlayer media3）语义要对应。
- ijkversion.h 由 compile-ijk.sh 预生成；Gradle 直接构建模块不经过它，
  依赖 CMake 的 sh 兜底或已生成文件。
