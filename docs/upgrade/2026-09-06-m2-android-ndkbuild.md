# M2 — Android ndk-build 适配（2026-09-06，Windows 主机）

## 目标
在 NDK r28（clang-only，Windows 主机）下跑通 `compile-ijk.sh`，产出
`libijkplayer.so` / `libijksdl.so`（与 M1 的 `libijkffmpeg.so` 组成完整播放器 native 层）。

## 已做

### jni 层结构（Windows 符号链接问题）
- `ijkplayer-arm64` / `ijkplayer-x86_64` 的 `src/main/jni/Android.mk` 由指向 armv7a 的
  git 符号链接改为**实体文件**（内容本就 ABI 无关：按 `TARGET_ARCH_ABI` 走 ifeq）；
  arm64 的 `jni/ffmpeg` 符号链接同样实体化（x86_64 本就是实体目录）。
  git 里用 `git rm --cached` + 重新 add 完成的 typechange（120000 → 100644）。
- `jni/ijkmedia`（指向仓库根 `ijkmedia/`）保留 git 符号链接（macOS 正常工作）；
  Windows 无符号链接权限时被 checkout 成文本文件，`compile-ijk.sh` 新增
  `fix_win_jni_links()`：检测到文本文件时删除并用 `cmd //c mklink //J` 建
  **NTFS 目录 junction**（无需管理员/开发者模式），构建结束不清理。
  ⚠️ Windows 会话提交时不要把该 worktree "删除" stage 进去。

### Application.mk（NDK r28 现代化）
- `APP_PLATFORM` android-21 → **android-24**（minSdk 24 目标值）；
- 删除 `NDK_TOOLCHAIN_VERSION=4.9`、`APP_PIE := false`（均已被 NDK 移除/失效）；
- `APP_STL: stlport_static` → **c++_static**（stlport 已从 NDK 移除）；
- 删除 `-Wa,--noexecstack`（clang 集成汇编器不接受）。

### compile-ijk.sh
- ABI 收窄：`all` = `arm64 x86_64`（armv5/armv7a/x86 分支与 all32 删除），默认目标 arm64；
- `-j` 并行数增加 `NUMBER_OF_PROCESSORS` 回退（Git Bash 无 nproc）；
- 新增 `run_ndk_build()`：Windows 下走 `cmd //c ndk-build.cmd`（NDK r28 Windows 无 bash 版 ndk-build），
  其余平台走原 `$ANDROID_NDK/ndk-build`；
- 失败退出码传播（`return $RET`），避免 `cd -` 吞掉 ndk-build 的失败状态；
- 构建前预生成 `ijkmedia/ijkplayer/ijkversion.h`：Android.mk 里的 `$(shell version.sh …)`
  在 Windows（make 的 shell 是 cmd.exe）下静默失败，导致 `ijkversion.h` 缺失。

### 共享层 n7.1 迁移尾巴（ijkmedia/，iOS 同样受益，已留 handoff）
- `ff_ffplay.c`：
  - 删除自引用的 `isnan` 宏 workaround（NDKr8e 时代产物；bionic math.h 已把 isnan 定义为
    宏，旧写法展开成不存在的函数声明报错）；
  - `stream_component_close` 里 `audio_filter_src.ch_layout` 的释放补 `#if CONFIG_AVFILTER`
    （上游 config.h 刻意关闭 avfilter，字段被裁剪，n7.1 迁移时新增的 uninit 没带 guard）；
  - 状态打印里被 n7.1 移除的 `AVCodecContext.pts_correction_num_faulty_{dts,pts}`
    （上游 ffplay 也一并删除了这两列）；
  - `ic->iformat->read_seek` → `ffifmt(is->ic->iformat)->read_seek`（回调移入 FFInputFormat）；
  - `AVFormatContext.filename` → `url`（3 处）；
  - `AVClass.child_class_next` → `child_class_iterate`。
- `ijkavformat/ijkasync.c`：旧 fifo API（`AVFifoBuffer`/`av_fifo_alloc/freep/reset/size/
  space/generic_peek_at/generic_write/drain`）全部迁移到 n7.1 `AVFifo` API；
  泛型回调（读侧 `fifo_do_not_copy_func` 跳过、写侧 `wrapped_url_read` 拉流）改为
  4KB 分块 staging 实现，语义保持。
- `ijkavformat/ijkasync.c` 之外的杂项：`ijkiocache.c` 补 `libavutil/error.h`（av_err2str）；
  `ijkiourlhook.c` 补 `<inttypes.h>/<stdio.h>/<stdlib.h>/<string.h>`（旧 FFmpeg 头失去传递
  include）；`ijklas.c` 补 `libavformat/internal.h`（avpriv_set_pts_info）。
- `ijkavutil/ijkdict.c`：`uintptr_t = NULL` → 0（同 M1 dict.c 的问题）；错调的
  `av_dict_get` → `ijk_av_dict_get`。
- `ffpipeline_android.c`：`int ret = NULL` → 0；
  `ffpipenode_android_mediacodec_vdec.c`：删除 `av_packet_split_side_data()` 调用（n7.1
  已移除该 API，side data 直接随包携带）。
- `ijksdl/ijksdl_egl.c`：显式 `#include <android/native_window.h>`。
- `ijkmedia/*/Android.mk`：`-std=c99` 从 `LOCAL_CFLAGS` 移到 `LOCAL_CONLYFLAGS`
  （否则 clang++ 拒绝，ijkstl.cpp 编译失败；c99 约束本身保留）。

### 补丁集（0303 新增，android/ios 同步）
- `libavcodec/Makefile` HEADERS 安装新增 `packet_internal.h`：已安装的
  `libavformat/internal.h` 引用它（id3v2.h → internal.h → packet_internal.h 链），
  不装则 ijklas.c 编译失败。两个 build tree 的 `output/include/libavcodec/` 已手工补拷。

### settings.gradle
- 修剪为 `:ijkplayer-arm64 :ijkplayer-x86_64 :ijkplayer-java :ijkplayer-exo :ijkplayer-example`
  （armv5/armv7a/x86 模块目录保留在磁盘上，不再进构建图）。

## 已验证
- `compile-ijk.sh arm64` / `compile-ijk.sh x86_64`：均 exit 0，产出
  `ijkplayer-<abi>/src/main/libs/<abi>/lib{ijkplayer,ijksdl,ijkffmpeg}.so`
  （gradle 模块经 `jniLibs.srcDirs 'src/main/libs'` 直接消费）。

## 已知问题 / 待办（转入 M3）
- [ ] ndk-build 警告 AndroidManifest `minSdkVersion 21` 与 APP_PLATFORM android-24 不一致
      ——M3 把模块 manifest/build.gradle 统一到 minSdk 24 时一并处理。
- [ ] 模块 build.gradle 仍是 AGP 旧语法（`compile`、`compileSdkVersion`），M3 统一迁移
      AGP 8.x / Gradle 8.x / AndroidX / Media3。
- [ ] `ijkversion.h` 由 compile-ijk.sh 预生成；M3 接 Gradle externalNativeBuild/预编译 .so
      时需确认生成时机（或改为 CI/init 阶段生成）。
- [ ] iOS 侧（M4，需 macOS）：ijkmedia 的全部 n7.1 迁移改动同样适用；见
      `docs/handoff/`。
