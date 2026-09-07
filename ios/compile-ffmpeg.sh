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

#----------
# modify for your build tool

FF_ALL_ARCHS_IOS13_SDK="arm64 arm64-sim x86_64-sim"

FF_ALL_ARCHS=$FF_ALL_ARCHS_IOS13_SDK

#----------
UNI_BUILD_ROOT=`pwd`
UNI_TMP="$UNI_BUILD_ROOT/tmp"
UNI_TMP_LLVM_VER_FILE="$UNI_TMP/llvm.ver.txt"
FF_TARGET=$1
FF_TARGET_EXTRA=$2
set -e

#----------
echo_archs() {
    echo "===================="
    echo "[*] check xcode version"
    echo "===================="
    echo "FF_ALL_ARCHS = $FF_ALL_ARCHS"
}

FF_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
do_lipo_ffmpeg () {
    LIB_FILE=$1
    DEST_DIR=$2
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        case "$ARCH" in *-sim) continue ;; esac
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        mkdir -p "$DEST_DIR"
        xcrun lipo -create $LIPO_FLAGS -output "$DEST_DIR/$LIB_FILE"
        xcrun lipo -info "$DEST_DIR/$LIB_FILE"
    fi
}

SSL_LIBS="libcrypto libssl"
do_lipo_ssl () {
    LIB_FILE=$1
    DEST_DIR=$2
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        case "$ARCH" in *-sim) continue ;; esac
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/openssl-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        mkdir -p "$DEST_DIR"
        xcrun lipo -create $LIPO_FLAGS -output "$DEST_DIR/$LIB_FILE"
        xcrun lipo -info "$DEST_DIR/$LIB_FILE"
    fi
}

do_lipo_all () {
    mkdir -p $UNI_BUILD_ROOT/build/universal/lib
    echo "lipo archs: $FF_ALL_ARCHS"
    for FF_LIB in $FF_LIBS
    do
        do_lipo_ffmpeg "$FF_LIB.a" "$UNI_BUILD_ROOT/build/universal/lib";
    done

    ANY_ARCH=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/include"
        if [ -d "$ARCH_INC_DIR" ]; then
            if [ -z "$ANY_ARCH" ]; then
                ANY_ARCH=$ARCH
                cp -R "$ARCH_INC_DIR" "$UNI_BUILD_ROOT/build/universal/"
            fi

            UNI_INC_DIR="$UNI_BUILD_ROOT/build/universal/include"

            mkdir -p "$UNI_INC_DIR/libavutil/$ARCH"
            cp -f "$ARCH_INC_DIR/libavutil/avconfig.h"  "$UNI_INC_DIR/libavutil/$ARCH/avconfig.h"
            cp -f tools/avconfig.h                      "$UNI_INC_DIR/libavutil/avconfig.h"
            cp -f "$ARCH_INC_DIR/libavutil/ffversion.h" "$UNI_INC_DIR/libavutil/$ARCH/ffversion.h"
            cp -f tools/ffversion.h                     "$UNI_INC_DIR/libavutil/ffversion.h"
            mkdir -p "$UNI_INC_DIR/libffmpeg/$ARCH"
            cp -f "$ARCH_INC_DIR/libffmpeg/config.h"    "$UNI_INC_DIR/libffmpeg/$ARCH/config.h"
            cp -f tools/config.h                        "$UNI_INC_DIR/libffmpeg/config.h"
        fi
    done

    for SSL_LIB in $SSL_LIBS
    do
        do_lipo_ssl "$SSL_LIB.a" "$UNI_BUILD_ROOT/build/universal/lib";
    done

    # device and arm64 simulator slices share the arm64 CPU type and cannot
    # be merged into one fat binary; keep a separate simulator universal tree
    SIM_ARCHS=
    DEV_ARM64=
    for ARCH in $FF_ALL_ARCHS
    do
        case "$ARCH" in
            *-sim) SIM_ARCHS="$SIM_ARCHS $ARCH" ;;
            arm64) DEV_ARM64=1 ;;
        esac
    done

    if [ -n "$SIM_ARCHS" ]; then
        SIM_UNI_ROOT="$UNI_BUILD_ROOT/build/universal-sim"
        mkdir -p "$SIM_UNI_ROOT/lib"
        echo "lipo sim archs:$SIM_ARCHS"

        SIM_LIPO=
        for ARCH in $SIM_ARCHS
        do
            SIM_LIB="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib"
            for FF_LIB in $FF_LIBS
            do
                if [ -f "$SIM_LIB/$FF_LIB.a" ]; then
                    SIM_LIPO=1
                fi
            done
        done

        if [ -n "$SIM_LIPO" ]; then
            for FF_LIB in $FF_LIBS
            do
                do_lipo_ffmpeg_sim "$FF_LIB.a" "$SIM_ARCHS" "$SIM_UNI_ROOT/lib";
            done
            for SSL_LIB in $SSL_LIBS
            do
                do_lipo_ssl_sim "$SSL_LIB.a" "$SIM_ARCHS" "$SIM_UNI_ROOT/lib";
            done

            ANY_SIM_ARCH=${SIM_ARCHS%% *}
            if [ -d "$UNI_BUILD_ROOT/build/ffmpeg-$ANY_SIM_ARCH/output/include" ]; then
                cp -R "$UNI_BUILD_ROOT/build/ffmpeg-$ANY_SIM_ARCH/output/include" "$SIM_UNI_ROOT/"
                SIM_INC_DIR="$SIM_UNI_ROOT/include"
                mkdir -p "$SIM_INC_DIR/libavutil/$ANY_SIM_ARCH"
                cp -f "$UNI_BUILD_ROOT/build/ffmpeg-$ANY_SIM_ARCH/output/include/libavutil/avconfig.h" "$SIM_INC_DIR/libavutil/$ANY_SIM_ARCH/avconfig.h"
                cp -f tools/avconfig.h                      "$SIM_INC_DIR/libavutil/avconfig.h"
                cp -f "$UNI_BUILD_ROOT/build/ffmpeg-$ANY_SIM_ARCH/output/include/libavutil/ffversion.h" "$SIM_INC_DIR/libavutil/$ANY_SIM_ARCH/ffversion.h"
                cp -f tools/ffversion.h                     "$SIM_INC_DIR/libavutil/ffversion.h"
                mkdir -p "$SIM_INC_DIR/libffmpeg/$ANY_SIM_ARCH"
                cp -f "$UNI_BUILD_ROOT/build/ffmpeg-$ANY_SIM_ARCH/output/include/libffmpeg/config.h" "$SIM_INC_DIR/libffmpeg/$ANY_SIM_ARCH/config.h"
                cp -f tools/config.h                        "$SIM_INC_DIR/libffmpeg/config.h"
            fi
        fi
    fi
}

do_lipo_ffmpeg_sim () {
    LIB_FILE=$1
    SIM_ARCHS=$2
    DEST_DIR=$3
    LIPO_FLAGS=
    for ARCH in $SIM_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        xcrun lipo -create $LIPO_FLAGS -output "$DEST_DIR/$LIB_FILE"
        xcrun lipo -info "$DEST_DIR/$LIB_FILE"
    fi
}

do_lipo_ssl_sim () {
    LIB_FILE=$1
    SIM_ARCHS=$2
    DEST_DIR=$3
    LIPO_FLAGS=
    for ARCH in $SIM_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/openssl-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        xcrun lipo -create $LIPO_FLAGS -output "$DEST_DIR/$LIB_FILE"
        xcrun lipo -info "$DEST_DIR/$LIB_FILE"
    fi
}

#----------
if [ "$FF_TARGET" = "arm64" -o "$FF_TARGET" = "arm64-sim" -o "$FF_TARGET" = "x86_64-sim" ]; then
    echo_archs
    sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
    do_lipo_all
elif [ "$FF_TARGET" = "lipo" ]; then
    echo_archs
    do_lipo_all
elif [ "$FF_TARGET" = "all" ]; then
    echo_archs
    for ARCH in $FF_ALL_ARCHS
    do
        sh tools/do-compile-ffmpeg.sh $ARCH $FF_TARGET_EXTRA
    done

    do_lipo_all
elif [ "$FF_TARGET" = "check" ]; then
    echo_archs
elif [ "$FF_TARGET" = "clean" ]; then
    echo_archs
    echo "=================="
    for ARCH in $FF_ALL_ARCHS
    do
        echo "clean ffmpeg-$ARCH"
        echo "=================="
        cd ffmpeg-$ARCH && git clean -xdf && cd -
    done
    echo "clean build cache"
    echo "================="
    rm -rf build/ffmpeg-*
    rm -rf build/openssl-*
    rm -rf build/universal/include
    rm -rf build/universal/lib
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh arm64|arm64-sim|x86_64-sim"
    echo "  compile-ffmpeg.sh lipo"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh check"
    exit 1
fi
