#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# M2+: ndk-build replaced by CMake (Ninja) via the NDK toolchain file.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IJK_ROOT=$(dirname "$SCRIPT_DIR")

# Derive ANDROID_NDK from ANDROID_HOME/ndk/28.* when not exported explicitly.
if [ -f "$SCRIPT_DIR/tools/env-ndk.sh" ]; then
    . "$SCRIPT_DIR/tools/env-ndk.sh"
fi

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK, ANDROID_SDK before starting."
    echo "They must point to your NDK and SDK directories.\n"
    exit 1
fi

REQUEST_TARGET=$1
REQUEST_SUB_CMD=$2
# modernized: arm64 + x86_64 only (armv5/armv7a/x86 pruned)
ACT_ABI_ALL="arm64 x86_64"
UNAME_S=$(uname -s)

# Pre-generate ijkversion.h; keeps it fresh even when CMake's execute_process
# hook cannot find a POSIX sh (e.g. Gradle builds without one).
sh "$IJK_ROOT/ijkmedia/ijkplayer/version.sh" \
   "$IJK_ROOT/ijkmedia/ijkplayer" \
   "$IJK_ROOT/ijkmedia/ijkplayer/ijkversion.h" >/dev/null

IJK_JOBS=
if which nproc >/dev/null
then
    IJK_JOBS=`nproc`
elif [ -n "$NUMBER_OF_PROCESSORS" ]
then
    # Git Bash on Windows has no nproc
    IJK_JOBS=$NUMBER_OF_PROCESSORS
elif [ "$UNAME_S" = "Darwin" ] && which sysctl >/dev/null
then
    IJK_JOBS=`sysctl -n machdep.cpu.thread_count`
fi

fix_win_jni_links () {
    # Windows checkouts without symlink support materialize git symlinks as
    # plain text files; replace the ijkmedia dir link with an NTFS junction
    # (mklink /J needs no privileges), so the build can descend into it.
    case "$UNAME_S" in
        MINGW*|MSYS*|CYGWIN*)
            JNI_DIR=$1
            LINK="$JNI_DIR/ijkmedia"
            if [ -f "$LINK" ]; then
                TARGET=$(cat "$LINK")
                ABS_TARGET=$(realpath -m "$JNI_DIR/$TARGET")
                rm "$LINK"
                cmd //c mklink //J "$(cygpath -w "$JNI_DIR/ijkmedia")" "$(cygpath -w "$ABS_TARGET")" >/dev/null
            fi
        ;;
    esac
}

ijk_cmake_abi () {
    case "$1" in
        arm64)  echo arm64-v8a ;;
        x86_64) echo x86_64 ;;
    esac
}

do_build () {
    PARAM_TARGET=$1
    CMAKE_ABI=$(ijk_cmake_abi $PARAM_TARGET)
    MAIN_DIR="$SCRIPT_DIR/ijkplayer/ijkplayer-$PARAM_TARGET/src/main"
    BUILD_DIR="$MAIN_DIR/obj/cmake"

    fix_win_jni_links "$MAIN_DIR/jni"

    mkdir -p "$BUILD_DIR"
    cmake -S "$MAIN_DIR/jni" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$CMAKE_ABI \
        -DANDROID_PLATFORM=android-24 \
        -DANDROID_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release \
        || return $?

    cmake --build "$BUILD_DIR" --parallel $IJK_JOBS || return $?

    mkdir -p "$MAIN_DIR/libs/$CMAKE_ABI"
    find "$BUILD_DIR" -name "libijk*.so" -exec cp {} "$MAIN_DIR/libs/$CMAKE_ABI/" \;
    # libijkffmpeg.so is a prebuilt IMPORTED library (see src/main/jni/CMakeLists.txt);
    # copy it alongside the CMake-built libs so the APK ships all three.
    IJK_FFMPEG_SO="$SCRIPT_DIR/contrib/build/ffmpeg-$PARAM_TARGET/output/libijkffmpeg.so"
    if [ -f "$IJK_FFMPEG_SO" ]; then
        cp "$IJK_FFMPEG_SO" "$MAIN_DIR/libs/$CMAKE_ABI/"
    else
        echo "!! libijkffmpeg.so not found at $IJK_FFMPEG_SO; run compile-ffmpeg.sh first"
        return 1
    fi
    echo "installed: $MAIN_DIR/libs/$CMAKE_ABI/lib{ijkplayer,ijksdl,ijkffmpeg}.so"
}

do_ndk_build () {
    PARAM_TARGET=$1
    PARAM_SUB_CMD=$2
    case "$PARAM_TARGET" in
        arm64|x86_64)
            case "$PARAM_SUB_CMD" in
                clean)
                    MAIN_DIR="$SCRIPT_DIR/ijkplayer/ijkplayer-$PARAM_TARGET/src/main"
                    rm -rf "$MAIN_DIR/obj/cmake" "$MAIN_DIR/libs"/*
                    return $?
                ;;
                *)
                    do_build $PARAM_TARGET
                    return $?
                ;;
            esac
        ;;
    esac
}

case "$REQUEST_TARGET" in
    "")
        do_ndk_build arm64;
    ;;
    arm64|x86_64)
        do_ndk_build $REQUEST_TARGET $REQUEST_SUB_CMD;
    ;;
    all)
        for ABI in $ACT_ABI_ALL
        do
            do_ndk_build "$ABI" $REQUEST_SUB_CMD || exit $?;
        done
    ;;
    clean)
        for ABI in $ACT_ABI_ALL
        do
            do_ndk_build "$ABI" clean;
        done
    ;;
    *)
        echo "Usage:"
        echo "  compile-ijk.sh arm64|x86_64"
        echo "  compile-ijk.sh all"
        echo "  compile-ijk.sh clean"
    ;;
esac
