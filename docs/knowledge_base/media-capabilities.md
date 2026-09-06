# ijkplayer 核心功能支持矩阵（已验证）

> 依据：`config/module-lite.sh`（默认构建档）+ 实际构建产物
> `android/contrib/build/ffmpeg-arm64/ffbuild/config.mak` 的 `FFMPEG_CONFIGURATION`
> （2026-09-06 核实一致）。改档位（lite-hevc / module-default）后以新 config 为准。
> 接入方法见 `sdk-user-guide.md`。

## 1. 容器 / 解封装（demuxers）

默认档（module-lite）**支持**：

| 格式 | demuxer | 典型扩展/说明 |
|---|---|---|
| MP4 / MOV / M4A | `mov` | 含 MOV/MP4/3GP 族 |
| HLS（m3u8） | `hls` | 直播/VOD 均可，配合 `concat` 分段 |
| FLV | `flv` | 含 HEVC-in-FLV（n7.1 原生支持取代 fork 补丁） |
| 直播 FLV | `live_flv` | ijk 扩展 |
| MPEG-TS | `mpegts` | 直播流常用 |
| MPEG-PS | `mpegps` | |
| MP3 | `mp3` | |
| AAC（ADTS） | `aac` | |
| FLAC | `flac` | |
| HEVC 裸流 | `hevc` | |
| concat 拼接 | `concat` | ijk 定制版（`AV_PKT_FLAG_NEW_SEG` 分段语义），HLS/多段场景 |
| data 流 | `data` | |
| WebM DASH manifest | `webm_dash_manifest` | 仅 manifest 解析 |
| ijk 协议封装 | `ijk*`（通配） | ijklas / ijklivehook 等 ijk 自定义协议的 demuxer 槽 |

默认档**不含**常见但未启用的：avi、mkv、webm（VP9 裸流可播，mkv 容器不行）、
ogg、wmv/asf、mov_muxer 之外的录制类。切 `module-default.sh` 全开（avi/mkv/ogg 等）。

## 2. 解码

软解（默认档启用）：
- 视频：`h264`、`hevc`、`vp8`、`vp9`、`vp6f`、`flv`（Sorenson H.263）
- 音频：`aac`、`aac_latm`、`mp3*`（mp3/mp3float/mp3on4 族）、`flac`

硬解（MediaCodec，ijk 自带 JNI 管线，**不走 FFmpeg mediacodec decoder**，
`CONFIG_MEDIACODEC=0` 是预期状态）：
- H.264（`mediacodec` / `mediacodec-avc`）、HEVC（`mediacodec-hevc`）
- 软解失败自动回落；`mediacodec-auto-rotate`、`mediacodec-handle-resolution-change`
  处理旋转与分辨率变化
- VP8/VP9 未接硬解管线（软解）

## 3. parsers

`aac`、`aac_latm`、`h264`、`flac`、`hevc`。

## 4. 网络协议

`--enable-protocols` 全开后再显式禁用一批，**实际可用**（常用）：

- `http` / `https`（TLS 由 `--enable-openssl` 提供，openssl 3.5 LTS）
- `file`、`fd`、`pipe`
- `rtmp`、`rtmpt`、`ffrtmphttp`（RTMP 直播推拉流）
- `tcp`、`udp`、`tls`
- `async`（ijk 异步 I/O）、`ijkio`/`cache`（边下边播，见 sdk-user-guide §7）
- ijk 自定义：`ijkurlhook`/`ijklongurl`/`ijksegment`（重连/分片 hook）、
  `ijkioffio`/`ijkioandroidio`、`ijklas`/`ijklivehook`
- `concat` 协议与 `crypto`/`subfile`/`md5`/`icecast`/`mmsh`/`mmst`/`rtp`/`srtp`/
  `sctp`/`gopher`/`librtmp*`/`libssh`/`bluray`/`unix` 在默认档**禁用**

TCP 层 ijk 扩展（FORMAT 选项）：`addrinfo_one_by_one`、`addrinfo_timeout`、
`dns_cache_timeout`、`dns_cache_clear`、`fastopen`。

## 5. 复用 / 编码能力边界

- muxer：仅 `mp4`（`--enable-muxer=mp4`）；encoder：仅 `png`。
- **ijkplayer 是播放器**：不含转码/录制/推流编码能力（flv/rtmp 推流仅封装了
  `movenc` 系 flv 写头工具类，未开放完整 mux 链路）。

## 6. bitstream filters（bsf）

`--enable-bsfs` 全开后禁用一组（chomp、dca_core、dump_extradata、
hevc_mp4toannexb、imx_dump_header、mjpeg2jpeg、mjpega_dump_header、
mov2textsub、mp3_header_decompress、mpeg4_unpack_bframes、noise、
remove_extradata、text2movsub、vp9_superframe、eac3_core）。
保留常用的 `aac_adtstoasc`（HLS→MP4 转封装依赖）等。

## 7. 档位差异（config/module*.sh）

| 档位 | 相对默认档（lite） |
|---|---|
| `module-lite.sh`（默认） | 上述精确清单 |
| `module-lite-hevc.sh` | 多 latm/loas/m4v、h263 族、vp6/vp6a demuxer/muxer（mpegts/mp4）、filters 开；**少** ijk* demuxer 通配、flac、vp8/vp9（选择档位前注意） |
| `module-default.sh` | decoder/demuxer/parser/bsf/protocol/filter 全开（体积最大） |

切换档位后必须 clean 重编 ffmpeg（`sh compile-ffmpeg.sh clean`），否则选项残留。

## 8. 播放器层特性（ijkplayer 自身，与 FFmpeg 档位无关）

- 硬解管线与软硬解自动回落、旋转/分辨率变化处理
- 变速播放 `setSpeed` + `soundtouch` 变速不变调
- 精确 seek（`enable-accurate-seek`）与起播定位（`seek-at-start`）
- ijkio 边下边播/缓存复用（共享 cache manager）
- 缓冲水位控制（first/next/last-high-water-mark-ms）、无限缓冲 `infbuf`
- DNS 缓存、getaddrinfo 超时/逐个解析、TCP fastopen（tcp.c ijk 扩展）
- 多音轨/字幕轨道切换、TimedText 字幕回调
- 首帧/seek 渲染事件上报（`VIDEO_RENDERING_START` / `VIDEO_SEEK_RENDERING_START`）
- 运行时统计（码率/缓存/丢帧/TCP 速度/流量）
- WakeMode、后台播放（`setKeepInBackground`）
- iOS 侧另有 VideoToolbox 硬解（`--disable-videotoolbox` 仅关 FFmpeg 层；
  ijk iOS 管线独立，见 handoff/upgrade 文档）
