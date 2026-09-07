#! /usr/bin/env bash
#
# verify-all.sh — 双平台全链路构建验证（CI 替代）
#
# 在无 CI 服务的前提下，把 M5 的"CI 验证"门槛降级为本地一键脚本：
# 串行跑 init → openssl → ffmpeg → ijk → gradle/xcodebuild 全链路，
# 任一步失败立即退出非零。macOS 跑 Android + iOS，Windows 跑 Android。
#
# 用法：
#   sh tools/verify-all.sh            # 全平台（当前主机支持的全部）
#   sh tools/verify-all.sh android    # 仅 Android
#   sh tools/verify-all.sh ios        # 仅 iOS（需 macOS）
#
# 退出码：0 = 全部通过；非 0 = 失败步骤（见输出）。

set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

UNAME=$(uname -s)
IS_MACOS=0
case "$UNAME" in
    Darwin) IS_MACOS=1 ;;
    MINGW*|MSYS*|CYGWIN*) : ;;
    *) echo "!! unsupported host: $UNAME (expect macOS or Windows Git Bash)"; exit 1 ;;
esac

REQUEST=$1
[ -z "$REQUEST" ] && REQUEST=all

step() {
    echo ""
    echo "===================="
    echo "[*] $1"
    echo "===================="
}

fail() {
    echo ""
    echo "!! VERIFY FAILED at: $1"
    exit 1
}

verify_android() {
    step "Android: init-android.sh"
    ./init-android.sh || fail "init-android.sh"

    step "Android: init-android-openssl.sh"
    ./init-android-openssl.sh || fail "init-android-openssl.sh"

    step "Android: compile-openssl.sh all"
    ( cd android/contrib && sh compile-openssl.sh all ) || fail "android openssl"

    step "Android: compile-ffmpeg.sh all"
    ( cd android/contrib && sh compile-ffmpeg.sh all ) || fail "android ffmpeg"

    step "Android: compile-ijk.sh all"
    ( cd android && sh compile-ijk.sh all ) || fail "android ijk"

    step "Android: gradlew assembleDebug"
    ( cd android/ijkplayer && ./gradlew assembleDebug ) || fail "android gradle"
}

verify_ios() {
    step "iOS: init-ios.sh all"
    ./init-ios.sh all || fail "init-ios.sh"

    step "iOS: compile-openssl.sh all"
    ( cd ios && sh compile-openssl.sh all ) || fail "ios openssl"

    step "iOS: compile-ffmpeg.sh all"
    ( cd ios && sh compile-ffmpeg.sh all ) || fail "ios ffmpeg"

    step "iOS: IJKMediaFramework (device arm64)"
    xcodebuild -project ios/IJKMediaPlayer/IJKMediaPlayer.xcodeproj \
        -scheme IJKMediaFramework -sdk iphoneos -configuration Release \
        ARCHS=arm64 build || fail "ios framework device"

    step "iOS: IJKMediaFramework (simulator arm64+x86_64)"
    xcodebuild -project ios/IJKMediaPlayer/IJKMediaPlayer.xcodeproj \
        -scheme IJKMediaFramework -sdk iphonesimulator -configuration Release \
        ARCHS="arm64 x86_64" FF_TARGET_SUBDIR=universal-sim build || fail "ios framework sim"

    step "iOS: IJKMediaFrameworkWithSSL (device arm64)"
    xcodebuild -project ios/IJKMediaPlayer/IJKMediaPlayer.xcodeproj \
        -scheme IJKMediaFrameworkWithSSL -sdk iphoneos -configuration Release \
        ARCHS=arm64 build || fail "ios withssl device"

    step "iOS: IJKMediaFrameworkWithSSL (simulator x86_64)"
    xcodebuild -project ios/IJKMediaPlayer/IJKMediaPlayer.xcodeproj \
        -scheme IJKMediaFrameworkWithSSL -sdk iphonesimulator -configuration Release \
        ARCHS=x86_64 FF_TARGET_SUBDIR=universal-sim build || fail "ios withssl sim"

    step "iOS: IJKMediaDemo (device arm64, unsigned)"
    xcodebuild -project ios/IJKMediaDemo/IJKMediaDemo.xcodeproj \
        -scheme IJKMediaDemo -sdk iphoneos -configuration Release \
        ARCHS=arm64 CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build || fail "ios demo device"

    step "iOS: IJKMediaDemo (simulator arm64+x86_64, unsigned)"
    xcodebuild -project ios/IJKMediaDemo/IJKMediaDemo.xcodeproj \
        -scheme IJKMediaDemo -sdk iphonesimulator -configuration Release \
        ARCHS="arm64 x86_64" FF_TARGET_SUBDIR=universal-sim \
        CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build || fail "ios demo sim"
}

case "$REQUEST" in
    android)
        verify_android
        ;;
    ios)
        if [ "$IS_MACOS" -ne 1 ]; then
            echo "!! iOS 验证仅支持 macOS"; exit 1
        fi
        verify_ios
        ;;
    all)
        verify_android
        if [ "$IS_MACOS" -eq 1 ]; then
            verify_ios
        fi
        ;;
    *)
        echo "Usage: sh tools/verify-all.sh [android|ios|all]"
        exit 1
        ;;
esac

echo ""
echo "===================="
echo "VERIFY ALL PASSED"
echo "===================="
