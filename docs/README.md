# ijkplayer 现代化文档索引

- `upgrade/`：过程文档（按阶段记录改动与验证）。
- `knowledge_base/`：长期有效知识（仅收录构建验证过的结论），**按需检索**：
  - `toolchain-baseline.md` — 工具链版本基线（NDK/SDK/ABI/iOS 部署版本）
  - `windows-build-env.md` — Windows 构建环境坑位（junction、MSYS、镜像、CRLF 等）
  - `ffmpeg-patch-workflow.md` — patches-ffmpeg7 补丁集生成与修错闭环
  - `android-build-system.md` — Android 构建体系（CMake native + Gradle）与全链路速查
  - `ai-session-protocol.md` — AI 会话协作规范（检索原则、文档产出时机、禁止事项、收口流程）
- `handoff/`：会话交接（由用户手动发起；每会话结束更新）。
- `version-plan.md`：版本/tag 路线图。
- 计划源：`.kilo/plans/1788505926274-ijkplayer-modernization-plan.md`（实现唯一 source of truth）。
