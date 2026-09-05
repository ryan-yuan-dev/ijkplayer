# M0 — 文档基线重写（2026-09-06，Windows 主机）

## 目标
把仓库文档从"旧上游 0.8.8 基线"切到现代化目标基线，作为后续 M1–M6 的依据。

## 改动
- `AGENTS.md`：按新目标重写——FFmpeg n7.1、NDK r28、minSdk 24 / compileSdk 36、iOS 13、ABI 仅 arm64+x86_64、Windows+macOS 双主机、patches-ffmpeg7 补丁机制、docs 体系、tag 方案。
- `docs/knowledge_base/toolchain-baseline.md`：iOS 最低版本修正为 **13.0**（旧记录 15.0 经用户确认作废）；补充 Windows 主机构建约束（无 `nproc`，用 `NUMBER_OF_PROCESSORS` 回退）。
- 新增 `docs/version-plan.md`：tag 方案 `v0.9.0-alpha.1 → beta.1 → rc.1 → v0.9.0` 及收口流程。
- 新增根目录 `CHANGELOG.md`（Keep a Changelog 格式）；`NEWS.md` 保留为上游历史记录，不再追加。

## 验证
纯文档改动，无构建影响；`git diff --stat` 审阅后提交。

## 决策记录
- iOS 最低 13（用户确认，覆盖 knowledge_base 旧值 15.0）。
- Android ABI 仅 arm64 + x86_64（用户确认；32 位模块在 M2 中删除）。
- `ijkplayer-exo` 升级到 Media3（用户确认，M3 实施）。
