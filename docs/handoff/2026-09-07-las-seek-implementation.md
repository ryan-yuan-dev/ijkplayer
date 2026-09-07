# Handoff — LAS seek 实现（2026-09-07 macOS 会话 → 新会话）

> 承接 `2026-09-07-rc2-android-smoke-seek-ios-test.md`。本会话完成 **LAS seek 功能实现**
> （`las_read_seek` 从假成功改为真跳转），arm64 + x86_64 两个 ABI 编译通过。
> **尚未做端到端播放验证**（无可用 las 服务端流），iOS 播放冒烟仍未开始。

## 一、会话目标与状态

- 目标：实现 LAS seek（用户诉求：seek 后画面跳到目标点直接播放，不等预加载）。
- 分支：`ryan-dev`；改动仅 `ijkmedia/ijkplayer/ijkavformat/ijklas.c`（共享源码，**未提交**）。
- 编译验证：`compile-ijk.sh arm64` / `x86_64` 均通过，`ijklas.c` 无新增警告（13 条警告全是既有代码）。

## 二、已做（设计 + 实现）

### 核心思路
las 没有可 seek 的文件，服务端靠 `startPts=<ts>` 参数决定从哪个 gop 起拉。seek = 让下载线程
带着新 `startPts` 重连，并丢弃旧位置已缓冲的 tag。

### 线程模型（关键，决定了同步方式）
- **demuxer 线程**（ffplay `read_thread`）：跑 `las_read_packet` **和** `las_read_seek`，
  两者同线程、从不并发。
- **下载线程** `PlayList_read_thread`：`GopReader_close`(switch_index++) → `GopReader_init`
  (拼 `startPts`) → `GopReader_download_gop`(下载 tag 入队)。
- 消费路径：`las_read_packet` → 内层 flv `av_read_frame` → 自定义 AVIO `playlist->pb`
  → `PlayList_read_data` → `TagQueue_get(block=1)`。

### 握手协议（本次新增）
1. `las_read_seek`（demuxer 线程）：
   - 拒 `AVSEEK_FLAG_BYTE`；无 `read_thread` 直接 `AVERROR(ENOSYS)`。
   - 时间戳换算：`avformat_seek_file` 在 n7.1 的 `seek_frame_internal` 里已把 timestamp
     **rescale 进默认流的 time_base** 才回调 `read_seek`，所以这里按 `stream_index`
     对应流的 time_base（无则用 `AV_TIME_BASE_Q`）经 `av_rescale_q` 转 ms，clamp >= 0。
     flv/las 的流 tb 是 1/1000 → 得到的值就是 ms，与 `startPts` 同一量纲。
   - 在 `tag_queue.mutex` 下 latch：`seek_request=1; seek_flushed=0; seek_pos_ms=ts_ms`。
   - 锁外 `TagQueue_flush` 清旧数据；清 `reading_tag`（让下次取新 tag）；
     `PlayList_close_parser` 关掉内层 flv parser 并回收 `pb.buffer`。
   - 再回锁置 `seek_flushed=1` + `SDL_CondSignal(q->cond)`，返回 0。
2. `PlayList_read_thread`（下载线程）循环顶部：见 `seek_request` 则在 `tag_queue.mutex` 下
   `SDL_CondWaitTimeout` 等 `seek_flushed`（100ms 一轮，最长 5s 超时兜底），成功后
   `gop_reader->last_gop_start_ts = seek_pos_ms`，然后**无论成败都清掉 request**
   （否则 `GopReader_download_gop` 立刻返回 → 空转），最后走正常的
   close→init(startPts=目标)→download 流程。
3. `TagQueue_put_abortable`（新，替代原 `TagQueue_put`）：**检查与插入在同一把
   `tag_queue.mutex` 下完成**，这是"flush 之后不可能再混入旧位置 tag"的关键——seeker 无法
   插在检查与插入之间。返回 <0 中止 / 0 入队（队列接管 buf）/ >0 有 seek 待处理（丢弃 tag，
   调用方重启 gop）。
4. `GopReader_download_gop`：循环顶部加 `seek_request` 早退；入队点改用
   `TagQueue_put_abortable`，>0 时 `return 0`（让外层重连）。
5. `las_read_packet`：开头若 `playlist->ctx == NULL`（seek 后的正常状态），先
   `PlayList_prepare_reading_tag`（阻塞等新一代首个 tag，它内嵌 flv header）再
   `PlayList_open_rep` 重建 parser。原来这里是直接 `AVERROR_EOF` 退出。

### 顺带修掉的问题
- **`PlayList_close_rep` / 新增 `PlayList_close_parser` 的 double free**：内层 flv demuxer
  **没有** `AVFMT_NOFILE`，`avformat_close_input` 会 `avio_closep()` 掉 `ctx->pb`，而
  `playlist->pb` 是 `ffio_init_context` 初始化的**内嵌结构体**（非堆分配），会被
  `avio_context_free` → `av_freep` 误释放，还会 `ffurl_close(opaque)` 重入网络栈。
  新增 `PlayList_close_parser`：先把 `ctx->pb = NULL` 再 close，并回收 `pb.buffer`
  （原代码每次 close 泄漏 32KB）。`PlayList_close_rep` 改为复用它，避免两处维护。
- **`realtime_url` 跨线程读写无同步**：新增 `url_mutex` + `current_url` 快照；
  `GopReader_init` 写完 URL 后拷一份，`PlayList_open_rep` 用快照
  `avformat_open_input`，不再直读 `gop_reader.realtime_url`（原 `// fix me` 注释所指问题）。
  注意 `GopReader_init` 全程持锁，中间不能对同一把锁再加锁。

## 三、下会话第一条命令

```bash
cd /Volumes/MacOS/Users/Ryan/workspace/codes/opensource/ijkplayer
git diff ijkmedia/ijkplayer/ijkavformat/ijklas.c   # 先看改动
# 若要重新编译：
cd android && ANDROID_NDK=/Volumes/MacOS/Users/Ryan/workspace/Ansjer/environments/Android/sdk/ndk/28.2.13676358 ./compile-ijk.sh arm64
```

## 四、未做 / 阻塞点

- **端到端未验证**：`las-tech.org.cn/kwai/*.flv` 死链，没有可用 las 服务端。要验证需
  用户提供可用流，或本地起支持 `?startPts=` 的 gop 切片 FLV 服务。
  验证标准：拖动进度条 → 画面跳目标附近关键帧并立即继续；日志无 `error while seeking`。
- **已知可接受局限**：seek 无法打断正在阻塞的 `recv`。`url_block_read` → `ffurl_read` 的
  poll 循环虽会查 `ff_check_interrupt`，但回调是 ffplay 的 `decode_interrupt_cb`，只返回
  `is->abort_request`，与 seek 无关。所以 seek 最多等待一个 tag 的下载（受 avio
  `timeout=10000000` µs = 10s 上界约束）。直播流数据持续流入，实际延迟是一个 tag；
  要解决需改 ffplay 的中断回调，超出本次范围（交接文档明确"播放器层无需改动"）。
- **ABR 与 seek 的交互**：seek 后 `last_gop_start_ts` 被强制设为目标值，随后
  `GopReader_download_gop` 在下一个 IDR 会再次按实际 pts 更新它，自适应逻辑
  （`next_expected_rep_index`）不受影响，但未实测。
- iOS 播放级冒烟未跑（沿用上一份交接的第四节）。

## 五、打不上的 hunk / 语义冲突

无补丁操作。但注意：`ijklas.c` 是共享源码，iOS 侧把 ijklas 放在 `ios/patches-ffmpeg7/`，
本次改动若需同步到 iOS，要走补丁路径而不是直接改源码（见上一份交接第七节）。
