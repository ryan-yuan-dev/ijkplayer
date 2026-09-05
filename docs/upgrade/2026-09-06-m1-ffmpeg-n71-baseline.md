# M1 — FFmpeg n7.1 基线补全（2026-09-06，Windows 主机）

## 目标
补齐 FFmpeg n7.1 基线：生成 patches-ffmpeg7 补丁集（恢复 ijklas/ijklivehook 功能）、
openssl 3.5 LTS、双平台脚本可跑，并在 Windows 上完成 Android 全链路 FFmpeg 编译验证。

## 补丁集生成方法（可复现）
1. `git clone https://github.com/Bilibili/FFmpeg.git extra/ffmpeg`（fork tag 基于上游 n4.0），
   补拉上游 tag：`git fetch https://github.com/FFmpeg/FFmpeg.git refs/tags/n4.0:refs/tags/n4.0 refs/tags/n7.1:refs/tags/n7.1`。
2. worktree：`git worktree add ../ffmpeg-merge -B ijk-n71 ff4.0--ijk0.8.8--20210426--001`
   → `git merge --no-commit n7.1`。
3. fork 未改动的冲突文件直接取 n7.1；fork 改过的 14 个文件手工解决（保留双方意图）。
4. 提交合并后 `git diff n7.1 ijk-n71` 按文件拆分为 `android/patches-ffmpeg7/*.patch`
   （约 31 个），并复制到 `ios/patches-ffmpeg7/`。

## 关键移植决策（n7.1 语义）
- **read_header2**：fork 把 `read_header2(AVFormatContext*, AVDictionary**)` 加在公共
  AVInputFormat 上；n7.1 回调已内部化 → 挂到 `FFInputFormat`（demux.h），open 流程在
  `libavformat/demux.c avformat_open_input()` 分发。ijkutils.c 的哑元 demuxer 槽也改为
  `FFInputFormat`，`ijkav_register_*_demuxer` 按 `sizeof(FFInputFormat)` 做 ABI 校验。
- **AV_PKT_FLAG_NEW_SEG 0x8000**：新增于 libavcodec/packet.h（concat 分段起始包标记）。
- **ijk demuxer 注册**：ijkplayer 侧 ijklas.c/ijklivehook.c 改用 `FFInputFormat`（公共字段
  走 `.p`），启动时经 `ijkav_register_ijk_demuxers()` 覆写 libijkffmpeg 内哑元槽；
  `av_find_input_format("ijklas")` 经 allformats.c 的 extern + configure 的
  `find_things_extern` 自动进入 demuxer_list（module-*.sh 已有 `--enable-demuxer=ijk*`）。
- **avc.h/avc.o/url.h/internal.h/avio_internal.h/flv.h/id3v2.h/os_support.h/metadata.h/demux.h**
  加入 libavformat HEADERS 安装（ijkplayer 源码依赖内部头）。
- **已废弃 flag**：`--enable-yasm` 移除（n7.1 不识别）；`--enable-runtime-cpudetect` →
  `--disable-runtime-cpudetect`（默认已开启）。
- flvdec 的 fork HEVC 支持被 n7.1 原生实现取代，直接取上游。

## Windows 主机构建环境（新增要求）
| 组件 | 说明 |
|---|---|
| NDK r28 | `sdkmanager "ndk;28.2.13676358"`（与 macOS 基线一致） |
| MSYS make | 原生 make 会把 `PERL5LIB` 的 POSIX 路径转成 `C:/...`（冒号被 perl 拆分）→ 用 msys 包的 make 放 `~/bin` |
| perl 模块 | MSYS perl 缺 `Locale::Maketext::Simple / ExtUtils::MakeMaker / Pod::Usage / Pod::Text / Pod::Simple / Pod::Escapes`，从 CPAN 解包到 `~/perl5-lib`，`export PERL5LIB=~/perl5-lib` |
| host 编译器 | 无 gcc → 用 VS2022 自带 clang（`VC/Tools/Llvm/x64/bin/clang.exe`，能自动定位 MSVC/SDK 头）；路径带空格，复制到 `~/bin/host-clang.exe` 后传 `--host-cc` |
| 环境变量 | `ANDROID_HOME`（系统已设）+ `ANDROID_NDK=$ANDROID_HOME/ndk/28.2.13676358` |

## 编译期修复（补丁集 + 构建脚本，2026-09-06 第二轮）
首轮 Windows 构建暴露的问题，全部已修并回写 worktree（merge commit amend）+ 重生成对应补丁：

**补丁集修复**（对应补丁已重新生成，android/ios 两份一致）：
- `application.c` 缺 `libavutil/mem.h`、`libavutil/time.h`；`application.h` 缺 `<stdint.h>`（0100/0101）。
- `dns_cache.h` 缺 `<stdint.h>`；`dns_cache.c` 缺 `libavutil/mem.h`/`<string.h>`/`<stdlib.h>`（0102/0103）。
- `dict.c`：合并时 `av_dict_iterate` 残留 fork 的 `!key` 判断（该函数无 key 参数）；fork 新增的
  `av_dict_get_intptr/av_dict_strtoptr` 里 `uintptr_t ptr = NULL` → `= 0`、`return NULL` → `return 0`
  （C99 下 NULL 即 `((void*)0)`，赋给整数类型报错）（0106）。
- `tcp.c`：`goto fail` → `fail1`（n7.1 `tcp_open` 只有 fail1 标签）；`tcp_fast_open` 里
  `ff_socket/ff_listen` 补第 4 参 `h`；补 `libavutil/avstring.h` include（0222）。
- `libavformat/Makefile`：fork 把 `avc.o` 加进了基础 OBJS，但其依赖的 `nal.o` 只在
  `CONFIG_ISO_WRITER`（module-lite 下关闭）时编译 → 把 `nal.o` 一并加入基础 OBJS（0202）。

**构建脚本修复**（`android/contrib/tools/do-compile-ffmpeg.sh`）：
- `RANLIB` 显式传 `llvm-ranlib` 全路径：NDK r28 Windows 工具链无 `aarch64-linux-android-ranlib`。
- 链接 libijkffmpeg.so 加 `-Wl,-Bsymbolic`：n7.1 新增 `libavutil/tx_float.c` 与
  `libavutil/aarch64/tx_float_neon.S` 跨对象引用全局表，单 .so 直链下全局符号可被抢占，
  lld 报 `R_AARCH64_ADR_PREL_PG_HI21 cannot be used against symbol`（上游按分库 + version
  script 构建，符号为 local，无此问题）。
- 链接对象收集改为**递归** `find *.o`：n7.1 把编解码器挪进子目录（`libavcodec/{aac,hevc,vvc,opus}/`），
  原来只收顶层 `*.o` 会缺 `ff_hevc_decoder`、`ff_aac_decoder`、各类 bsf 等符号。

## 已验证（Windows，2026-09-06 最终）
- `init-android.sh`：克隆 ffmpeg-arm64/x86_64（extra/ffmpeg 作 reference）→ `checkout n7.1`
  → 31 个补丁全部干净应用；openssl/libyuv/soundtouch/config 正常。
- `compile-openssl.sh all`：openssl-3.5.8 产出 `build/openssl-{arm64,x86_64}/output/lib/lib{ssl,crypto}.a`。
- `compile-ffmpeg.sh arm64` + `compile-ffmpeg.sh x86_64`：均 exit 0，产出
  `build/ffmpeg-{arm64,x86_64}/output/libijkffmpeg.so`（28.6MB / 30.0MB）。

## 已知问题 / 待办
- [ ] `init-android.sh` 不幂等：重复运行时补丁二次应用而失败（与上游一致，后续加检测）。
- [ ] http.c 中 fork 的 `int len` 在 http_connect 未使用（仅 warning），下次动补丁时顺手清理。
- [ ] libyuv/soundtouch 仍用 Bilibili fork：上游 lemenkov/libyuv 无 ndk-build 所需
      Android.mk，直接切换会破坏 `yuv_static` 构建，暂保留（低优先级）。
- [ ] x86_64 缺 nasm 时自动 `--disable-x86asm`（性能降级），CI/正式构建建议安装 nasm。
