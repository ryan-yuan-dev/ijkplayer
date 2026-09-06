# AI 会话协作规范

> 本篇是 AI 会话在本仓库工作的约定。仓库级指令以根目录 `AGENTS.md` 为准，本篇补充流程细节。

## 检索原则

- 会话只需知道 `docs/knowledge_base/` 索引（`docs/README.md`）**存在**；
  遇到具体问题时按需查对应条目，不要求通读。
- 知识库只收**已验证结论**（构建通过才算）；过程性叙事写 `docs/upgrade/`，不进知识库。

## handoff（跨平台/跨会话交接）

- handoff 由**用户手动发起**：会话不自动读取 handoff 文档、不自动触发交接，
  也不把 handoff 内容并入知识库。
- 用户明确要求"按 handoff 继续"时，读 `docs/handoff/` 中用户指定的文档执行。
- 单平台会话完成另一平台相关改动后，**写** `docs/handoff/` 交接文档
  （打不上的 hunk、待验证项逐条记录，禁止静默丢弃）——这是 AGENTS.md 的硬性约定。

## 文档产出时机

| 时机 | 产出 | 位置 |
|---|---|---|
| 里程碑/阶段完成 | 阶段记录（目标、改动、验证结果、待办） | `docs/upgrade/YYYY-MM-DD-mN-主题.md` |
| 跨平台改动 | 交接文档 | `docs/handoff/` |
| 可复用的踩坑结论 | 收进知识库对应主题文档（没有就新建单主题文档） | `docs/knowledge_base/` |
| 里程碑收口 | CHANGELOG.md（Keep a Changelog）+ NEWS.md（上游格式追加） | 仓库根 |

## 禁止事项（源码与构建）

- 勿改生成文件：`ijkmedia/ijkplayer/ijkversion.h`（version.sh 生成）、`extra/`、
  `android/ffmpeg-*`、`ios/ffmpeg-*`、`android/contrib/build/`（均 gitignore，
  重跑 init 会重建）。
- 勿把 `android/ijkplayer/ijkplayer-*/src/main/jni/ijkmedia` 的本地"删除"或
  junction 内容 stage 进提交（Windows junction 详见 `windows-build-env.md`）。
- `ijkmedia/ijkplayer/Android.mk` 的 `-std=c99`（现为 CMake `CMAKE_C_STANDARD 99`）
  必须保留；32 位 ABI 分支（armv5/armv7a/x86）不要加回。
- 迁移到 FFmpeg n7.1 的 C 层改动用 `/* n7.1: ... */` 注释标记（见 `ff_ffplay.c`）。
- 改 FFmpeg 相关源码必须走补丁闭环（见 `ffmpeg-patch-workflow.md`）。

## 收口流程（tag）

1. 以构建验证为准（无测试/lint）：全链路构建通过 + 产物存在；
2. 更新 CHANGELOG.md / NEWS.md；
3. 按 `docs/version-plan.md` 打 annotated tag 并 push（`--follow-tags`）。
   已打：`v0.9.0-alpha.1`（M1）、`v0.9.0-beta.1`（M2+M3）；待打：`rc.1`（M4+M5）、`v0.9.0`。
4. `version.sh` 的版本号 bump 只在 `v0.9.0` 终版执行。
