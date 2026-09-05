# Handoff — 2026-09-06 M1 会话（Windows 主机）

> **收尾更新（同日晚些）**：M1 Windows 构建验证全部完成——`libijkffmpeg.so` 双 ABI
> （arm64/x86_64）均产出，exit 0。tcp.c 补丁已用修复后的 worktree 重新生成；额外修复
> application.c/dns_cache/dict.c 的 include 与 `uintptr_t` 问题、Makefile 补 `nal.o`、
> 构建脚本 RANLIB=llvm-ranlib、链接加 `-Wl,-Bsymbolic`、对象递归收集。详见
> `docs/upgrade/2026-09-06-m1-ffmpeg-n71-baseline.md` 的"编译期修复"与"已验证"章节。
> 下一步直接从 M2（Android ndk-build）开始。

## 本会话目标
M0（文档基线）+ M1（FFmpeg n7.1 基线补全）——见 `docs/upgrade/` 两份阶段记录与 `docs/version-plan.md`。

## 已做（已提交并 push 到 origin/ryan-dev，HEAD=bfe91e94 + 本次收口提交）
- M0：AGENTS.md 重写、toolchain-baseline（iOS 13）、docs/version-plan.md、CHANGELOG.md、docs/upgrade/M0 记录。commit `3e1469d5`。
- M1 补丁集：`extra/ffmpeg-merge`（worktree，分支 ijk-n71）中把 fork tag `ff4.0--ijk0.8.8--20210426--001` 三方合并到 n7.1，
  按文件拆成 31 个补丁到 `android/patches-ffmpeg7/` + `ios/patches-ffmpeg7/`。要点：
  - read_header2 挂到 FFInputFormat（demux.h/demux.c）；ijkutils.c 哑元槽改为 FFInputFormat（按 sizeof(FFInputFormat) ABI 校验）；
  - AV_PKT_FLAG_NEW_SEG 0x8000 加进 libavcodec/packet.h；
  - ijklas.c/ijklivehook.c 转为 FFInputFormat 并在 allformats.c 的 ijkav_register_ijk_demuxers() 启动注册（Android.mk 已重新启用）；
  - avc.h/url.h/internal.h/demux.h 等加入 libavformat HEADERS 安装。
- M1 脚本：openssl 3.5.8 切换（init + do-compile 重写，android/ios）；init-ios.sh 切 n7.1+补丁+arm64/arm64-sim/x86_64-sim；
  do-compile-ffmpeg.sh 加 Windows host tag、host-cc 回退、nasm 缺失回退；env-ndk.sh 路径规范化 + NDK 29.* 容忍；
  init-config.sh 修复 MSYS 假符号链接；.gitattributes 强制 *.sh LF。
- **Windows 构建验证**：openssl-3.5.8 双 ABI ✅（build/openssl-{arm64,x86_64}/output/lib/*.a）；
  FFmpeg arm64 configure ✅、make 进行到 libswscale 附近，**还剩少量编译错误未清**（见下）。

## 未做 / 下会话从这继续
1. **修 FFmpeg 剩余编译错误并完成 arm64/x86_64 构建**（最高优先）：
   - 已知错误（/tmp/ff-arm64.log，可能需重跑才能看到最新）：
     a) `libavutil/application.c`：`av_mallocz/av_free` 未声明 → 已给 worktree 和两个 build tree 的
        application.c 加 `#include "libavutil/mem.h"`、`libavutil/time.h`，application.h 加 `#include <stdint.h>`，
        补丁 0100/0101 已重新生成——**需确认 build tree 文件确实已改**（此前一次修复因宏续行反斜杠未匹配而落空，
        类似 ijkutils.c 的教训：替换锚必须带上行尾 `\`）。
     b) `libavformat/ijkutils.c` `.p.priv_data_size` → 已改为 `.priv_data_size`（FFInputFormat 顶层字段），补丁 0200 已重生成，build tree 已改。
     c) `libavformat/hls.c` `reset_packet` → 已改 `av_packet_unref(pls->pkt)`，补丁 0216 已重生成，build tree 已改。
     d) `libavformat/tcp.c`：`goto fail` → `fail1`（tcp_open 只有 fail1 标签）、tcp_fast_open 里 ff_socket/ff_listen 补第 4 参 `h`、
        补 `#include "libavutil/avstring.h"`——worktree 和 build tree 都已改，但**0222-libavformat-tcp-c.patch 还没用修复后的 worktree 重新生成**！
        生成命令：`git -C extra/ffmpeg-merge diff n7.1 HEAD -- libavformat/tcp.c > android/patches-ffmpeg7/0222-libavformat-tcp-c.patch && cp 同 ios/`。
   - 构建命令（必须含 MSYS make + PERL5LIB）：
     ```
     export PATH=$HOME/bin:$PATH
     export ANDROID_NDK="$ANDROID_HOME/ndk/28.2.13676358"
     export PERL5LIB=$HOME/perl5-lib
     cd android/contrib && set -o pipefail && sh compile-ffmpeg.sh arm64
     ```
   - 注意：`sh compile-ffmpeg.sh all | tail` 会吞退出码，必须 `set -o pipefail`。
   - 成功标志：`build/ffmpeg-arm64/output/libijkffmpeg.so` 与 `build/ffmpeg-x86_64/output/libijkffmpeg.so` 存在。
   - 修完所有错误后：worktree 里的最终改动要 re-amend 进 merge commit 并重新生成对应补丁，保证补丁与源码一致。
2. M1 收口提交：docs/upgrade/M1 记录（已写好 docs/upgrade/2026-09-06-m1-ffmpeg-n71-baseline.md，构建验证段落需按最终结果修订）+ CHANGELOG。
3. M2：Android ndk-build（Application.mk 等）→ M3：Gradle/Media3 → M4：iOS（需 macOS，写 handoff）→ M5：CI → M6：tag v0.9.0-alpha.1。

## 阻塞点
- 无硬阻塞。Windows 环境约束都已在 `docs/knowledge_base/toolchain-baseline.md` 与 M1 升级记录中写明
  （MSYS make 在 ~/bin、perl 模块在 ~/perl5-lib + PERL5LIB、host-clang 在 ~/bin/host-clang.exe、NDK r28）。

## 打不上的 hunk / 语义冲突记录
- 无静默丢弃。全部冲突显式解决：flvdec/flv.h 取 n7.1（HEVC 已原生支持）；utils.c 取 n7.1（逻辑移植进 demux.c）；
  mov.c 采样选择保留 fork 的 best_pos_sample 启发式并融合 n7.1 的 dts 守卫；concatdec/hls/http/tcp 逐条见 worktree 提交历史。

## 下会话第一条命令
```
cd /c/Users/ryany/ryan-workspace/opensource/ijkplayer && export PATH=$HOME/bin:$PATH && export ANDROID_NDK="$ANDROID_HOME/ndk/28.2.13676358" && export PERL5LIB=$HOME/perl5-lib && cd android/contrib && set -o pipefail && sh compile-ffmpeg.sh arm64 2>&1 | tail -5; ls -la build/ffmpeg-arm64/output/libijkffmpeg.so
```
