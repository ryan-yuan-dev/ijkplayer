# M3 — Gradle 8.x / AGP 8.x / AndroidX / Media3（2026-09-06，Windows 主机）

## 目标
Android 全链路收口：Gradle 构建现代化到 AGP 8.x / Gradle 8.x / AndroidX，`ijkplayer-exo`
切换到 androidx.media3，example 可 `assembleDebug` 产出可安装 APK（含双 ABI native 库）。

## 构建体系
- Gradle wrapper 2.14.1 → **8.11.1**（wrapper jar/脚本从 gradle/gradle v8.11.1 拉取）；
  AGP 2.1.3 → **8.10.1**（JDK 17+；本机 `JAVA_HOME=~/.jdks/ms-17.0.16`）。
- 仓库源：`google()` + `mavenCentral()`，另加 **Aliyun 镜像兜底**（本机直连
  repo.maven.apache.org TLS 握手被断，见已知问题）。
- `settings.gradle` 增加 `pluginManagement` / `dependencyResolutionManagement`；
  productFlavors `all32/all64` 移除（32 位 ABI 已裁剪），example 直接依赖
  `:ijkplayer-arm64` + `:ijkplayer-x86_64`。
- bintray / android-maven-gradle-plugin / gradle-on-demand 等发布期脚本全部解绑
  （`tools/gradle-*.gradle` 保留在仓库但不再 apply）。

## 模块改造
- 全部模块：AGP 8 必填的 `namespace` 写入 build.gradle；manifest 去掉
  `package=` 与 `uses-sdk`；`lint { abortOnError false }`；androidTest 的
  `ApplicationTest` 桩删除（依赖旧 instrumentation API，AGP 8 下无法编译）。
- `compileSdk/targetSdk 36`、`minSdk 24`（AGENTS 现代化目标值）。
- `gradle.properties`：`android.useAndroidX=true`、`org.gradle.parallel=true`。

## ijkplayer-exo → Media3
- 原 wrapper 基于 **ExoPlayer r1.5**（DemoPlayer + RendererBuilder + EventLogger），
  media3 下该架构整体过时，`demo/` 包删除。
- `IjkExoMediaPlayer`（`IMediaPlayer` facade）重写为 androidx.media3 `ExoPlayer`
  直连：`Player.Listener` 映射 ijk 事件（prepared/completion/buffering/
  video-size/rotation/error），HLS/DASH/SS 由 `DefaultMediaSourceFactory` 自动承载；
  `setLooping/setVolume/getAudioSessionId/getBufferedPercentage` 均实现
  （r1.5 版是 no-op 或抛异常）。
- 依赖：media3-exoplayer + hls/dash/smoothstreaming/datasource（`1.8.0`）。

## example AndroidX 迁移
- 22 个源文件 `android.support.*` → `androidx.*`（appcompat/fragment/loader/
  core/cursoradapter/drawerlayout/annotation/preference）。
- styles.xml 原本就是 AppCompat 主题且带 `preferenceTheme`，无需改。
- manifest：intent-filter 的 activity 显式 `android:exported="true"`（Android 12+ 要求）。

## 已验证
- `./gradlew assembleDebug`：BUILD SUCCESSFUL。
- `ijkplayer-example-debug.apk` 包含 `lib/{arm64-v8a,x86_64}/lib{ijkplayer,ijksdl,ijkffmpeg}.so`
  全部 6 个 native 库 + media3 依赖 dex。

## 已知问题 / 待办
- [ ] 本机直连 mavenCentral TLS 被断 → settings.gradle 里有 Aliyun 镜像兜底；
      CI（M5）环境无此问题，可自行裁剪。
- [ ] example 尚未真机/模拟器冒烟播放（可后续 `emulator` + 安装验证，M6 前做一次）。
- [ ] `tools/gradle-mvn-push.gradle` 等发布脚本未迁移（发 Maven Central 属 1.0.0 范围）。
