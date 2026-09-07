# Handoff — rc.2 收口 / LAS seek 实现 / iOS 实机测试（2026-09-07 Android 实机会话 → 新会话）

> 本会话在 macOS 上完成 Android 真机（SDK 36 / arm64，Xiaomi 24117RK2CC）冒烟，
> 收口 `v0.9.0-rc.2` 并推送。遗留两项待新会话完成：**LAS seek 功能实现**、
> **iOS 实机/模拟器播放测试**。以下信息足够新会话直接开工。

## 一、会话目标与状态

- 本会话目标：Android 真机冒烟 + demo 可用性修复 + `v0.9.0-rc.2` 收口 + 规划 seek/iOS 交接。
- 已收口：`v0.9.0-rc.2`（tag + push 完成，`origin/ryan-dev` 同步至 `e44b6ffc`）。
- 分支：`ryan-dev`；`origin` = 自有 fork，`upstream` = bilibili 官网（只读）。

## 二、已做（验证过的结论）

### rc.2 内容（commit 均已 push）
- `e54d3181 fix(ijkmedia): ijklas cache_ptr option string form for FFmpeg 7`
  - `ijklas.c` 的 `video_cache_ptr`/`audio_cache_ptr` AVOption 从 `AV_OPT_TYPE_INT64`
    改为 `AV_OPT_TYPE_STRING`（`.str = NULL`），struct 字段改 `char*`，read_header 用
    `strtoull` 解回指针。原因：FFmpeg 7 用 double 校验 int64 选项，MTE tagged 指针
    （arm64 地址 `0xb4...`，> 2^63）必越界 → `avformat_open_input` 返回 -10000。
    这是 las manifest 此前点击即报 `Error (-10000,0)` 的根因。改后 las 已能走通
    manifest 解析 → 真实拉流（`GopReader_init`/`ffurl_open_whitelist`）阶段。
- `6392f0e7 feat(example): AndroidX cleanup, edge-to-edge insets, sample list UX`
  - `activity_player.xml`/`widget_toolbar.xml`：`android.support.*` → androidx 等价类
    （demo 之前残留旧 support 引用导致启动即 `ClassNotFoundException` 崩溃）。
  - `AppActivity.java`/`VideoActivity.java`：`ViewCompat.setOnApplyWindowInsetsListener`
    给 toolbar/root 加 system bar inset——targetSdk 36 强制 edge-to-edge，之前 toolbar
    画进状态栏、按钮被状态栏拦截点不到。**注意用 API**：`androidx.core.view.OnApplyWindowInsetsListener`
    （顶层接口，非 `ViewCompat.OnApplyWindowInsetsListener` 内部类），
    `getInsets` 返回 `androidx.core.graphics.Insets`。
  - `SampleMediaListFragment.java`：sample 列表副标题单行省略（`setSingleLine`+
    `ellipsize`），首行 las test 副标题改为短文本 "LAS multi-bitrate adaptive manifest"
    （原先是整段 JSON manifest 撑爆行高）；长按 item 复制 `名称\n内容` 到剪贴板 + Toast。
  - `strings.xml`：`VideoView_error_text_unknown` 由 "Unknown" 改为友好文案
    "Unable to play this media. Check that the URL is reachable and try again."。
- 实机验证结果：
  - bipbop HLS（`bipbop_16x9_variant.m3u8`）真机正常播放：无错误弹窗、媒体控制器显示
    播放进度（约 `01:44 / 30:00`）、无 `FFP_MSG_ERROR`。截图留存 `/tmp/ijk_play.png`。
  - las test 项点击：manifest 解析成功进入拉流，因 **las-tech.org.cn/kwai/*.flv 服务端
    已死链**（curl 8 秒无响应，根路径 200）最终超时弹友好错误。**非播放器缺陷**，
    如需恢复演示需换可用 las 服务端流。
- 先前的收口文档/记录仍有效：`docs/upgrade/2026-09-07-m4-ios-fullchain.md`、
  `docs/version-plan.md`（新增 `v0.9.0-rc.2` 门槛行）。

## 三、任务 1：LAS seek 功能（新会话主任务）

### 用户诉求（原话归纳）
1. 当前 cache 进度条已够长，seek 后播放停在 seek 处不立即前进；
2. seek 应跳转目标点直接播放，**尚未预加载的部分不等下载完成**，到点就放。

### 代码现状（已定位）
- `ijklas.c` 的 demuxer seek 回调是空实现（约 `1993-1997` 行）：
  ```c
  static int las_read_seek(AVFormatContext* s, int stream_index,
                            int64_t timestamp, int flags) {
      return 0;
  }
  ```
  → ffplay `read_thread` 调 `avformat_seek_file` 返回 0（假成功），随即 flush 各
  packet_queue 并置 flush_pkt；但 las 内部 `PlayList_read_thread`/`GopReader_download_gop`
  仍在旧位置读旧 Gop，新位置数据不来 → 播放停住。
- las 定位机制**已具备**：`GopReader_init` 拼 URL 带 `startPts=<ts>` 参数
  （`ijklas.c:1011-1031`），`GopReader_download_gop` 在关键帧切换/新开连接时更新
  `reader->last_gop_start_ts`（`ijklas.c:1144`）。即服务端按 `startPts` 支持从任意
  gop 起拉，seek 应复用它。
- 关键结构/线程（`ijklas.c`，行号为当前 HEAD 值）：
  - `PlayList`（154-194）：`gop_reader`、`tag_queue`、`read_thread`、`cur_switch_index`、
    `read_abort_request`、`rw_mutex`。
  - `GopReader`（141-152）：`realtime_url`、`input`、`last_gop_start_ts`、`abort_request`、
    `switch_index`、`rep_index`。
  - `PlayList_read_thread`（1313-1355）：循环 GopReader_close → GopReader_init →
    GopReader_download_gop。
  - `GopReader_download_gop`（1061-1231）：下载 FLV tag 入 `tag_queue`；在 IDR 处更新
    `last_gop_start_ts` 并决定是否切 rep。
  - `PlayList_read_data`（1265-1284）：喂给内部 `AVFormatContext ctx`（`avformat_open_input`
    在 `PlayList_open_rep`，约 1394 行用 `gop_reader.realtime_url`）。
  - `TagQueue`（含 abort/cond）；`FlvTag` 由解码线程消费。
- 播放器层 seek 入口无需改动（ffplay `avformat_seek_file` 已正确下发；`IjkMediaPlayer.seekTo`
  → JNI → `ijkmp_seek_to` → ffplay `stream_seek` → `avformat_seek_file`）。

### 实现思路（建议，供新会话验证取舍）
核心是让 las 在收到 seek 后：**abort 当前 gop 下载 → 丢弃 tag_queue 中旧位置缓存 →
按 seek ts 重新 GopReader_init（startPts=目标 gop 起点）→ 让 ffplay 读到的第一个
tag 是关键帧**。要点：
1. `las_read_seek` 里：
   - 换算 `timestamp`（AV_TIME_BASE 或 stream time_base）为 gop 对齐的
     `last_gop_start_ts`（对齐到目标所在 gop 起点，最好取下一 IDR）；
   - 置 `PlayList`/`GopReader` 的 seek 请求标记 + `read_abort_request` 让
     `PlayList_read_thread`/`GopReader_download_gop` 退出当前循环（注意与用户 stop
     的 abort 区分，别误触发关闭线程）；
   - 丢弃已缓冲 `tag_queue` 数据（TagQueue 需加 flush/reset），并让内部 `ctx`
     （FLV parser）重新从新 URL 起读，保证新首帧是关键帧。
2. **立即播放（不等加载）**：las 当前是"下载整 Gop 入 queue → ffplay 消费"，seek 后
   若服务端按 gop 返回且首包即关键帧，ffplay flush 后第一帧即可显示；若想更激进，
   参考 `start-on-prepared`/`packet-buffering` 选项语义确认不会卡在 buffering。
3. 注意线程安全：`las_read_seek` 在 ffplay read 线程回调，与 `PlayList_read_thread`
   并发，需用现有 `rw_mutex`/cond 协调；`PlayList_reset_state`（1286）已置
   `cur_switch_index=0` 可复用。
4. 参考 FFmpeg 其它直播/切片 demuxer 的 seek 实现（hls.c `read_seek`/`read_seek2`
   思路：切换内部 playlist/重置 seq）。上游对比参照：
   `extra/patchgen/ffmpeg-bilibili-ijk/libavformat/hls.c`（同一仓库内的 bilibili fork
   源码）。

### 验证方法
- 需要**可用的 las 服务端流**。las-tech.org.cn/kwai/*.flv 已死链，两个选项：
  a) 用户提供可用 las/自适应 FLV 流与 manifest；
  b) 临时用本地起一个支持 `?startPts=` 的切片 FLV 服务（如按 gop 切 ts/flv + http
   range/query），或把 ijklas 的 seek 逻辑先移植验证。
- 验证标准：播放中拖动进度条（demo 媒体控制器）→ 画面跳到目标附近关键帧并立即继续；
  日志无 `error while seeking`，`FFP_MSG_ERROR` 不出现。
- Android 设备 adb 已就绪（USB 设备 `b4c242c8`）；构建命令见第四节。

## 四、任务 2：iOS 播放测试（待新会话，仅 macOS）

- M4 已构建通过（`tools/verify-all.sh all` → `VERIFY ALL PASSED`，真机 arm64 +
  universal-sim 全部 BUILD SUCCEEDED），**但尚未做过播放级冒烟**（没有跑过模拟器/
  真机上的实际播放验证）。M4 详情：`docs/upgrade/2026-09-07-m4-ios-fullchain.md`。
- 待办：
  1. 启动 iOS 模拟器（Apple Silicon，arm64-sim 产物），跑 `IJKMediaDemo`；
  2. 拉一个 sample（demo 内置 bipbop HLS / 或用户提供 URL）验证实际播放；
  3. （可选）真机：需开发者签名，装 framework+demo 实播；
  4. 注意：ijklas cache_ptr 的 string 改动是共享 `ijkmedia/`，iOS 侧编译不受影响但
     若 iOS 也用 ijklas 需确认 option 表一致（iOS 侧当前把 ijklas 放 patches-ffmpeg7，
     见 `ios/patches-ffmpeg7/`，如改动涉及需同步补丁而非源码）。
- 模拟器播放验证命令参考：`xcodebuild -project ios/IJKMediaDemo/IJKMediaDemo.xcodeproj
  -scheme IJKMediaDemo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
  build`；产物 framework 链接的是 `build/universal-sim/`（FF_TARGET_SUBDIR 机制）。

## 五、环境备忘（本会话已验证）

- 设备：Xiaomi `24117RK2CC`（zorn），Android 15 / SDK 36，arm64；USB 调试 OK，demo
  已装（`tv.danmaku.ijk.media.example`）。安装注意 MIUI 弹窗需手动允许。
- demo 安装：`adb install -r android/ijkplayer/ijkplayer-example/build/outputs/apk/debug/ijkplayer-example-debug.apk`
- 常用 native 日志：`adb logcat | grep IJKMEDIA`；ffmpeg 层 tag 为 `IJKFFMPEG`。
- 前台易被本机其它 app（微信/美团等）抢占，操作 UI 前先 `dumpsys window | grep mCurrentFocus` 确认。
- sample 列表操作路径：launcher 打开 demo → FileExplorerActivity 顶部 **Sample** →
  SampleMediaActivity 列表 → 点行播放 / 长按复制。
- 本机 Android NDK：`/Volumes/MacOS/Users/Ryan/workspace/Ansjer/environments/Android/sdk/ndk/28.2.13676358`。

## 六、未做 / 阻塞点

- LAS seek 未实现（上文三）。
- las-tech.org.cn 测试流死链，las 播放入口无法端到端验证（除非用户提供可用流）。
- iOS 播放级冒烟未跑（上文四）。
- `v0.9.0` 终版待 iOS 实机/模拟器冒烟通过后 `version.sh` bump（0.8.8 → 0.9.0）再打 tag。

## 七、打不上的 hunk / 语义冲突

无（本轮无补丁操作；ijklas.c 改动落在共享源码而非 patches-ffmpeg7，若后续要同步到
iOS 的 ijklas 补丁注意是补丁路径）。
