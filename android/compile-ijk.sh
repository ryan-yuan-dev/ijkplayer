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

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK, ANDROID_SDK before starting."
    echo "They must point to your NDK and SDK directories.\n"
    exit 1
fi

REQUEST_TARGET=$1
REQUEST_SUB_CMD=$2
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IJK_ROOT=$(dirname "$SCRIPT_DIR")

# Pre-generate ijkversion.h: the $(shell) call in ijkplayer/Android.mk is
# unreliable when make's shell is cmd.exe (Windows), so generate it here.
sh "$IJK_ROOT/ijkmedia/ijkplayer/version.sh"    "$IJK_ROOT/ijkmedia/ijkplayer"    "$IJK_ROOT/ijkmedia/ijkplayer/ijkversion.h" >/dev/null
# modernized: arm64 + x86_64 only (armv5/armv7a/x86 pruned)
ACT_ABI_ALL="arm64 x86_64"
UNAME_S=$(uname -s)

FF_MAKEFLAGS=
if which nproc >/dev/null
then
    FF_MAKEFLAGS=-j`nproc`
elif [ -n "$NUMBER_OF_PROCESSORS" ]
then
    # Git Bash on Windows has no nproc
    FF_MAKEFLAGS=-j$NUMBER_OF_PROCESSORS
elif [ "$UNAME_S" = "Darwin" ] && which sysctl >/dev/null
then
    FF_MAKEFLAGS=-j`sysctl -n machdep.cpu.thread_count`
fi

fix_win_jni_links () {
    # Windows checkouts without symlink support materialize git symlinks as
    # plain text files; replace the ijkmedia dir link with an NTFS junction
    # (mklink /J needs no privileges), so ndk-build can descend into it.
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

run_ndk_build () {
    case "$UNAME_S" in
        MINGW*|MSYS*|CYGWIN*)
            # NDK on Windows ships ndk-build.cmd only
            cmd //c "$(cygpath -w "$ANDROID_NDK/ndk-build.cmd")" "$@"
        ;;
        *)
            "$ANDROID_NDK/ndk-build" "$@"
        ;;
    esac
}

do_sub_cmd () {
    SUB_CMD=$1
    if [ -L "./android-ndk-prof" ]; then
        rm android-ndk-prof
    fi

    if [ "$PARAM_SUB_CMD" = 'prof' ]; then
        echo 'profiler build: YES';
        ln -s ../../../../../../ijkprof/android-ndk-profiler/jni android-ndk-prof
    else
        echo 'profiler build: NO';
        ln -s ../../../../../../ijkprof/android-ndk-profiler-dummy/jni android-ndk-prof
    fi

    case $SUB_CMD in
        prof)
            run_ndk_build $FF_MAKEFLAGS
        ;;
        clean)
            run_ndk_build clean
        ;;
        rebuild)
            run_ndk_build clean
            run_ndk_build $FF_MAKEFLAGS
        ;;
        *)
            run_ndk_build $FF_MAKEFLAGS
        ;;
    esac
}

do_ndk_build () {
    PARAM_TARGET=$1
    PARAM_SUB_CMD=$2
    case "$PARAM_TARGET" in
        arm64|x86_64)
            cd "ijkplayer/ijkplayer-$PARAM_TARGET/src/main/jni"
            fix_win_jni_links "$(pwd)"
            if [ "$PARAM_SUB_CMD" = 'prof' ]; then PARAM_SUB_CMD=''; fi
            do_sub_cmd $PARAM_SUB_CMD
            RET=$?
            cd -
            return $RET
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
            do_ndk_build "$ABI" $REQUEST_SUB_CMD;
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

