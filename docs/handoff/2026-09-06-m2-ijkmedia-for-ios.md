# Handoff — M2 ijkmedia 共享层改动（2026-09-06 Windows 会话 → macOS/iOS 会话）

M2（Android ndk-build）在跑通过程中对 `ijkmedia/`（Android/iOS 共享核心）做了一批
n7.1 迁移修复。这些改动**同样适用于 iOS 侧编译**（`ios/IJKMediaPlayer` 直接编译
`ijkmedia/` 源码），已在 Windows 上通过 arm64/x86_64 ndk-build 验证；macOS 跑 iOS
构建前无需再做源码改动，但需注意以下几点。

## 需要同步到 iOS 构建环境的
1. **`libavcodec/packet_internal.h` 需要进头文件安装列表**：
   新补丁 `ios/patches-ffmpeg7/0303-libavcodec-Makefile.patch`（与 android 侧一致）。
   链路：`ijklas.c` → `libavformat/internal.h` → `libavcodec/packet_internal.h`。
   iOS 的 `ios/compile-ffmpeg.sh` 重新走 init/补丁流程即可；若 build tree 已存在，
   需 clean 后重打补丁（`cd ios && ./compile-ffmpeg.sh clean`）。

## 源码层面（已改完，无需动作，仅供 review）
- `ff_ffplay.c`：isnan 宏 workaround 删除；`audio_filter_src` uninit 加
  `#if CONFIG_AVFILTER`；`pts_correction_num_faulty_{dts,pts}` 统计列删除；
  `ffifmt(...)->read_seek`；`AVFormatContext.url`；`child_class_iterate`。
- `ijkavformat/ijkasync.c`：旧 fifo API → n7.1 `AVFifo`（分块 staging 保持回调语义）。
- `ijkavformat/{ijkiocache,ijkiourlhook,ijklas}.c`：补缺失 include（error.h、
  inttypes/stdio/stdlib/string、internal.h）。
- `ijkavutil/ijkdict.c`：`uintptr_t` 的 NULL → 0；`av_dict_get` → `ijk_av_dict_get`。
- `ffpipeline_android.c` / `ffpipenode_android_mediacodec_vdec.c`：Android 专属，
  iOS 不受影响。
- `ijksdl/ijksdl_egl.c` 补 `<android/native_window.h>`：Android 专属。
- `ijkmedia/{ijkplayer,ijksdl,ijkj4a}/Android.mk` 的 `-std=c99` → `LOCAL_CONLYFLAGS`：
  仅影响 ndk-build，iOS 不用 Android.mk。

## 验证状态
- Android：`compile-ijk.sh arm64 / x86_64` exit 0（Windows + NDK r28）。
- iOS：未验证（需 macOS）。iOS 编译 ijkmedia 时如遇上述之外的 n7.1 API 差异，
  按 `/* n7.1: ... */` 注释风格就近处理并回写 `docs/upgrade/`。
