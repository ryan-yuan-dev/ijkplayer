# ijkplayer Android SDK 接入指南（user guide）

> 面向 App 接入者。功能支持范围（格式/协议/硬解）见 `media-capabilities.md`；
> 本文基于 2026-09-06 现代化分支（FFmpeg n7.1 + Gradle 8.x）验证。

## 1. 模块与依赖

| 模块 | 作用 | 接入者是否需要 |
|---|---|---|
| `ijkplayer-java` | Java API（`tv.danmaku.ijk.media.player.*`），纯 Java 无 native | **必须** |
| `ijkplayer-arm64` / `ijkplayer-x86_64` | 预编译 `lib{ijkplayer,ijksdl,ijkffmpeg}.so`（jniLibs 壳） | **按 ABI 引入** |
| `ijkplayer-exo` | media3 后端（`IjkExoMediaPlayer`），可选的播放器实现 | 可选 |
| `ijkplayer-example` | Demo（`IjkVideoView` 控件可抄/直接用） | 参考 |

源码依赖（与 example 相同）：

```gradle
dependencies {
    implementation project(':ijkplayer-java')
    implementation project(':ijkplayer-arm64')     // 真机
    implementation project(':ijkplayer-x86_64')    // 模拟器
    // 可选 media3 后端：
    // implementation project(':ijkplayer-exo')
}
```

- requirements：minSdk 24+，AGP 8.x / Gradle 8.x（JDK 17+）。
- ProGuard：各模块未携带 keep 规则、也不需要；若混淆后出问题可自行
  keep `tv.danmaku.ijk.media.player.**`。

## 2. native 库加载

`IjkMediaPlayer` 构造时自动加载 `ijkffmpeg` → `ijksdl` → `ijkplayer` 三个 so。
自定义加载方式（插件化/热载场景）用 `IjkLibLoader`：

```java
IjkMediaPlayer.loadLibrariesOnce(libLoader); // 传 null = 默认 System.loadLibrary
IjkMediaPlayer.native_profileBegin("libijkplayer.so"); // 可选 profiler（dummy 版为 no-op）
// ... 退出时：
IjkMediaPlayer.native_profileEnd();
```

## 3. 最小接入

### 方式 A：直接用 player（不依赖 example）

```java
IjkMediaPlayer player = new IjkMediaPlayer();
player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1);
player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "timeout", 10_000_000L);
player.setOnPreparedListener(mp -> mp.start());
player.setDataSource(context, uri);                    // 或 (String path)、(fd)、headers 重载
player.setSurface(surface);                            // 或 setDisplay(surfaceHolder)
player.prepareAsync();
// ... 释放：
player.stop();
player.release();
```

注意：`start-on-prepared` 默认 0 时需在 `onPrepared` 里手动 `start()`。

### 方式 B：IjkVideoView（example 的封装，可直接抄）

```java
IjkMediaPlayer.loadLibrariesOnce(null);
IjkMediaPlayer.native_profileBegin("libijkplayer.so");
mVideoView = findViewById(R.id.video_view);
mVideoView.setVideoPath(path);          // 或 setVideoURI(uri)
mVideoView.start();
```

`IjkVideoView`（example/widget/media）封装了 surface 渲染（TextureView/SurfaceView）、
MediaController、播放器后端切换，可直接复制到业务工程。

## 4. 数据源

- `setDataSource(Context, Uri)` / `(String path)` / `(String path, Map headers)`
  / `(Context, Uri, Map headers)`：headers 会转成 FORMAT 类 `"headers"` 选项
  （UserAgent/Referer/Cookie 等）。
- `setDataSource(FileDescriptor)`：本地 fd（content:// 场景先 `openFileDescriptor`）。
- 自定义数据源：实现 `misc.IMediaDataSource`（readAt/getSize/close）后
  `setDataSource(IMediaDataSource)`；自定义 I/O 回调用 `setAndroidIOCallback(IAndroidIO)`
  （open/read/seek/close）。

## 5. 事件与状态

8 个监听器（`AbstractMediaPlayer` 提供 setter）：`OnPreparedListener`、
`OnCompletionListener`、`OnBufferingUpdateListener`、`OnSeekCompleteListener`、
`OnVideoSizeChangedListener`、`OnErrorListener`、`OnInfoListener`、
`OnTimedTextListener`（字幕）。

常用 `MEDIA_INFO_*`（定义在 `IMediaPlayer`）：`VIDEO_RENDERING_START=3`（首帧）、
`BUFFERING_START=701` / `BUFFERING_END=702`、`VIDEO_ROTATION_CHANGED=10001`、
`MEDIA_ACCURATE_SEEK_COMPLETE=10100`；错误 `MEDIA_ERROR_*`：`IO=-1004`、
`MALFORMED=-1007`、`UNSUPPORTED=-1010`、`TIMED_OUT=-110`。

运行时统计 getter：`getVideoCachedDuration/Bytes/Packets`、`getAudioCached*`、
`getTrafficStatisticByteCount`、`getTcpSpeed`、`getBitRate`、`getDropFrameRate`、
`getSeekLoadDuration`。

## 6. 选项体系（setOption）

`setOption(int category, String name, long|String value)`，category 四类：

| 常量 | 值 | 去向 |
|---|---|---|
| `OPT_CATEGORY_FORMAT` | 1 | demuxer/协议层（AVFormatContext 选项 + ijk 扩展协议选项） |
| `OPT_CATEGORY_CODEC` | 2 | 解码器层（AVCodecContext 选项） |
| `OPT_CATEGORY_SWS` | 3 | 像素转换 |
| `OPT_CATEGORY_PLAYER` | 4 | ijkplayer 播放行为（`ff_ffplay_options.h`） |

常用 PLAYER 选项：

| 选项 | 说明 |
|---|---|
| `mediacodec` / `mediacodec-auto-rotate` / `mediacodec-hevc` / `mediacodec-handle-resolution-change` | MediaCodec 硬解开关（默认关；支持范围见 media-capabilities.md） |
| `opensles` | OpenSL ES 音频输出（默认 Audiotrack） |
| `start-on-prepared` | prepared 后自动开播 |
| `enable-accurate-seek` | 精确 seek（配合 `MEDIA_ACCURATE_SEEK_COMPLETE`） |
| `seek-at-start` | 起播定位 |
| `max-buffer-size` / `min-frames` / `packet-buffering` / `infbuf` | 缓冲策略 |
| `first/next/last-high-water-mark-ms` | 起播/续播水位 |
| `framedrop` | 音画不同步丢帧 |
| `fast` | 快速启动（跳过部分探测） |
| `max-fps` | 限帧 |
| `soundtouch` | 变速不变调（配合 `setSpeed(float)`） |
| `overlay-format`（fcc-yv12/fcc-rv16/fcc-rv32） | 输出像素格式 |
| `loop` / `an` / `vn` / `nodisp` / `volume` | 循环/纯音/纯视/无显示/音量 |

FORMAT 类常用：`timeout`、`reconnect`、`probesize`、`analyzeduration`、
rtmp 的 `rtmp_buffer` 等；ijkio 缓存组见第 7 节。

## 7. 边下边播 / 本地缓存（ijkio）

`ijkio:` 协议把 I/O 委托给 ijkiomanager，支持缓存落盘与复用：

```java
player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "cache_file_path",
        new File(context.getCacheDir(), "video.cache").getAbsolutePath());
player.setDataSource("ijkio:" + url);   // cache: 前缀等价
```

相关 FORMAT 选项：`cache_file_forwards_capacity`、`cache_max_capacity`、
`cache_map_path`、`parse_cache_map`、`cache_file_close`。

## 8. 多后端切换

`ijkplayer-example` 的 `IjkVideoView.createPlayer()` 演示三后端同接口切换：
`IjkMediaPlayer`（native，全功能含 setOption/setSpeed）、`IjkExoMediaPlayer`
（androidx.media3，无 setOption/setSpeed）、`AndroidMediaPlayer`（系统 MediaPlayer）。
三者都实现 `IMediaPlayer`，业务侧可用工厂按设备/场景选择。

## 9. 字幕与音轨

`getTrackInfo()` 返回 `IjkTrackInfo[]`（轨道类型见 `ITrackInfo.MEDIA_TRACK_TYPE_*`）；
`selectTrack(int)` / `deselectTrack(int)` / `getSelectedTrack(int)` 切换；
字幕内容经 `OnTimedTextListener` 回调。

## 10. 调试

- `IjkMediaPlayer.native_setLogLevel(IjkMediaPlayer.IJK_LOG_DEBUG)` 控制日志级别；
- `getColorFormatName(int)` 辅助排查 MediaCodec 色彩格式；
- 模拟器（x86_64）与真机（arm64）双 ABI 均有预编译产物。
