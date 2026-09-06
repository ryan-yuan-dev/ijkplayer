# Windows 构建环境坑位（已验证）

> 全部结论在 Windows 11 + Git Bash（MSYS2）+ NDK r28 + CMake/Ninja（VS 2022 自带）上验证通过（2026-09-06，M1–M3 全链路构建）。
> 工具链版本基线见 `toolchain-baseline.md`。

## git 符号链接 → NTFS junction

- 仓库内 `android/ijkplayer/ijkplayer-<abi>/src/main/jni/ijkmedia` 是指向仓库根
  `ijkmedia/` 的 git 符号链接。Windows 无符号链接权限（未开开发者模式/非管理员）时，
  checkout 出来是**内容为链接目标的纯文本文件**，构建无法穿越。
- `android/compile-ijk.sh` 内置 `fix_win_jni_links()`：检测到文本文件时删除并
  `cmd //c mklink //J` 建 NTFS 目录 junction（无需管理员权限）。
- **提交红线**：junction 会让 `git status` 显示 `ijkmedia` 为本地"删除"（worktree-only）。
  提交时**严禁**把它 stage 进去（macOS 侧仍需符号链接）：
  ```
  git add -A -- <path> ':(exclude)android/ijkplayer/ijkplayer-arm64/src/main/jni/ijkmedia' \
                    ':(exclude)android/ijkplayer/ijkplayer-x86_64/src/main/jni/ijkmedia'
  ```
- **教训**：`git add -A`（不带 exclude）会把 junction 当目录递归展开，本会话曾三次
  误扫 212 个文件（含 ijkyuv/ijksoundtouch 内嵌 git repo）进 index。提交前务必
  `git status --short` 检查 `jni/ijkmedia/` 下是否出现新增条目。

## FFmpeg configure 前置（compile-ffmpeg.sh 依赖）

```bash
export PATH=$HOME/bin:$PATH                  # MSYS make 放 ~/bin（原生 make 会破坏 PERL5LIB 的 POSIX 路径）
export ANDROID_NDK="$ANDROID_HOME/ndk/28.2.13676358"
export PERL5LIB=$HOME/perl5-lib              # MSYS perl 缺的 CPAN 模块解包在此
```
- host 编译器：无 gcc → 用 VS2022 自带 clang 复制到 `~/bin/host-clang.exe`（路径含空格不能直接传）。
- **管道吞退出码**：`sh compile-ffmpeg.sh all | tail` 会让失败显示为成功，必须 `set -o pipefail`。
- 构建目录在 `android/contrib/build/ffmpeg-<abi>/`；改 configure 参数后需 clean 重编
  （脚本检测到已有 config.mak 会跳过 configure）。

## ijkversion.h 生成坑

- `ijkmedia/ijkplayer/Android.mk`（ndk-build 时代）用 `$(shell version.sh ...)` 生成
  `ijkversion.h`；Windows 下 ndk-build 的 make shell 是 cmd.exe，`.sh` 脚本**静默执行失败**。
- 现由 `android/compile-ijk.sh` 每次构建前预生成；CMake 里另有 `find_program(sh)` 的
  execute_process 兜底（找不到 sh 时跳过）。该文件是生成物，勿手工编辑、勿提交。

## 网络间歇 TLS 断连

- 症状：`schannel: failed to receive handshake` / `SSL routines::unexpected eof`，
  对 `repo.maven.apache.org`、`github.com` 间歇性出现（阿里云等国内源正常）。
- mavenCentral：`android/ijkplayer/settings.gradle` 已配 Aliyun 镜像兜底
  （gradle-plugin/central/public 三个仓库）。
- github push 失败：同症状，间隔数分钟重试即可恢复；openssl/schannel 后端切换无效
  （网络层问题）。

## 其他

- **CRLF**：`.gitattributes` 强制 `*.sh` LF；用 python 编辑文件时显式传
  `newline=''` 读写并检测现有行尾（本会话多处文件是 CRLF，锚点替换需带 `\r\n`）。
- **pyenv shim**：`python` 偶发报 "Access is denied" + pyenv 版本提示，重跑即可。
- **并行度**：Git Bash 无 `nproc`，脚本回退 `NUMBER_OF_PROCESSORS`（compile-ijk.sh、
  do-compile-ffmpeg.sh 均已内置）。
- **ndk-build.cmd**（历史）：NDK r28 Windows 无 bash 版 ndk-build，需 `cmd //c ...ndk-build.cmd`；
  native 层已改 CMake（见 `android-build-system.md`），此处仅作背景。
