# patches-ffmpeg7 — ijk 定制补丁集（打在上游 n7.1 上）

来源：对比 `Bilibili/FFmpeg@ff4.0--ijk0.8.8--20210426--001` 与上游 `n4.0`
抽取的 ijk 定制（R1 回退语义：功能等价即可，不追求逐行一致）。

内容（按计划 A2）：
- `ijk*` protocol/demuxer 新增文件（`libavformat/ijk*.c`、`libavformat/ijklivehook.c` 等）
- `libavformat/allformats.c` / `libavformat/protocols.c` 注册项
- `async` / `ffrtmphttp` 等 protocol 定制

应用方式（`init-android.sh` / `init-ios.sh` 已接入）：
`patch -p1 < ../../patches-ffmpeg7/*.patch`，失败即停（`set -e`）。

状态：待生成。生成条件：本地 `extra/ffmpeg`（上游 n4.0 基线）与
Bilibili fork `ff4.0--ijk0.8.8--20210426--001` 均已拉取后，运行：

    sh android/patches-ffmpeg7/generate.sh

打不上的 hunk 逐个记入 `docs/handoff/`，禁止静默丢弃。
