# patches-ffmpeg7 补丁集工作流（已验证）

> ijk 对 FFmpeg 的定制不再改 fork 源码，而是以补丁集打到上游 n7.1 上。
> 补丁集位于 `android/patches-ffmpeg7/` 与 `ios/patches-ffmpeg7/`，**两份必须逐字节一致**。

## 合并模型

- `extra/ffmpeg-merge` 是 Bilibili FFmpeg fork 仓库的 worktree，分支 `ijk-n71`：
  在 fork tag `ff4.0--ijk0.8.8--20210426--001` 基础上三方合并上游 `n7.1`，
  一个 merge commit 承载全部 ijk 定制（HEAD = merge commit）。
- `git diff n7.1 HEAD -- <file>` 按文件拆成约 32 个补丁（0100/01xx libavutil、
  0200/02xx libavformat、03xx libavcodec）。
- 补丁由 `init-android.sh` / `init-ios.sh` 在拉取的 `ffmpeg-<abi>` 目录内以
  `patch -p1` 应用；补丁文件**必须以换行结尾**（无尾换行会导致 patch 应用失败）。

## 修错闭环（改了 FFmpeg 相关源码后）

```
1. 在 extra/ffmpeg-merge 修源码
2. git -C extra/ffmpeg-merge commit --amend --no-edit   # 收进 merge commit
3. git -C extra/ffmpeg-merge diff n7.1 HEAD -- <file> > android/patches-ffmpeg7/<NNNN>-<name>.patch
4. cp 到 ios/patches-ffmpeg7/（保持两份一致）
5. 同步改 android/contrib/ffmpeg-{arm64,x86_64} 两个 build tree 的同名文件
   （init 不重跑时 build tree 不会自动重打补丁；同名补丁重生成后 clean 才会重新应用）
```

- build tree 里的 ffmpeg 源码目录是 gitignore 的（`android/contrib/ffmpeg-*`），
  重跑 init 会重新克隆+打补丁，手工改动会丢——**所有修复必须最终落在 worktree 里**。

## 一致性校验

```bash
for f in android/patches-ffmpeg7/*.patch; do
  cmp -s "$f" "ios/patches-ffmpeg7/$(basename $f)" || echo "DIFF: $f"
done
```

## 关键补丁语义备忘（n7.1 迁移点）

- **read_header2**：fork 的 `read_header2(AVFormatContext*, AVDictionary**)` 挂到
  `FFInputFormat`（demux.h），分发逻辑在 `libavformat/demux.c`；ijkutils.c 的哑元
  demuxer 槽同为 `FFInputFormat`（按 `sizeof(FFInputFormat)` ABI 校验）。
- **priv_data_size**：n7.1 中已从 `AVInputFormat` 移到 `FFInputFormat` 顶层字段；
  demuxer 初始化写 `.priv_data_size`（不是 `.p.priv_data_size`）。
- **read_probe**：FFInputFormat 顶层字段，签名 `int (*)(const AVProbeData *)`。
- **0303-libavcodec-Makefile**：HEADERS 安装 `packet_internal.h`。
  依赖链：`ijklas.c` → `libavformat/id3v2.h` → `libavformat/internal.h` →
  `libavcodec/packet_internal.h`；缺它则 ijkplayer 编译失败。
  注意已安装的 internal.h 仍用 `avpriv_set_pts_info`（n7.1 未改名）。
- **0202-libavformat-Makefile**：基础 OBJS 含 `avc.o` 与 `nal.o`（fork 把 avc.o
  提进基础列表，但其依赖 nal.o 原本只在 ISO_WRITER（module-lite 关闭）下编译）。
- **0222-libavformat-tcp.c**：`goto fail`→`fail1`（tcp_open 只有 fail1 标签）、
  `ff_socket/ff_listen` 补第 4 参 `h`、补 `libavutil/avstring.h`。
- **0106-libavutil-dict.c**：`av_dict_iterate` 不能带 fork 旧 `!key` 判断；
  fork 新增 `av_dict_strtoptr` 等 `uintptr_t` 不可赋 `NULL`（用 0）。
- 构建脚本侧配套改动（不属于补丁但强相关）：`do-compile-ffmpeg.sh` 的
  `RANLIB=llvm-ranlib`（NDK r28 Windows 无 triple 前缀 ranlib）、链接
  `-Wl,-Bsymbolic`（tx_float asm 跨对象引用）、**递归**收集 `*.o`
  （n7.1 编解码器在 `libavcodec/{aac,hevc,vvc,opus}/` 子目录）。

## 已知边界

- fork 的 HEVC flv 支持被 n7.1 原生实现取代（flvdec 取上游）。
- `libyuv/`、`soundtouch/`（ijkmedia 下 vendored fork）不在补丁体系内，
  仍由 `init-android-libyuv.sh` / `init-android-soundtouch.sh` 拉取。
