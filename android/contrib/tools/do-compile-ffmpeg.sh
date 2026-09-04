#! /usr/bin/env bash
#
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

# Modernized for NDK r28 + FFmpeg n7.1 (clang-only, arm64/x86_64 only, 16K pages).

#--------------------
echo "===================="
echo "[*] check env $1"
echo "===================="
set -e


#--------------------
# common defines
FF_ARCH=$1
FF_BUILD_OPT=$2
echo "FF_ARCH=$FF_ARCH"
echo "FF_BUILD_OPT=$FF_BUILD_OPT"
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm64, x86_64'."
    echo ""
    exit 1
fi


FF_BUILD_ROOT=`pwd`
FF_ANDROID_API=24


FF_BUILD_NAME=
FF_SOURCE=
FF_CROSS_PREFIX=
FF_LLVM_TRIPLE=
FF_DEP_OPENSSL_INC=
FF_DEP_OPENSSL_LIB=

FF_DEP_LIBSOXR_INC=
FF_DEP_LIBSOXR_LIB=

FF_CFG_FLAGS=

FF_EXTRA_CFLAGS=
FF_EXTRA_LDFLAGS=
FF_DEP_LIBS=

FF_MODULE_DIRS="compat libavcodec libavfilter libavformat libavutil libswresample libswscale"
FF_ASSEMBLER_SUB_DIRS=


#--------------------
echo ""
echo "--------------------"
echo "[*] check NDK env"
echo "--------------------"
. ./tools/do-detect-env.sh
FF_MAKE_FLAGS=$IJK_MAKE_FLAG


#----- arch begin -----
if [ "$FF_ARCH" = "x86_64" ]; then
    FF_BUILD_NAME=ffmpeg-x86_64
    FF_BUILD_NAME_OPENSSL=openssl-x86_64
    FF_BUILD_NAME_LIBSOXR=libsoxr-x86_64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=x86_64-linux-android
    FF_LLVM_TRIPLE=x86_64-linux-android${FF_ANDROID_API}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=x86_64 --enable-yasm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="x86"

elif [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME=ffmpeg-arm64
    FF_BUILD_NAME_OPENSSL=openssl-arm64
    FF_BUILD_NAME_LIBSOXR=libsoxr-arm64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=aarch64-linux-android
    FF_LLVM_TRIPLE=aarch64-linux-android${FF_ANDROID_API}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=aarch64 --enable-yasm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="aarch64 neon"

else
    echo "unknown architecture $FF_ARCH (only arm64/x86_64 supported)";
    exit 1
fi

if [ ! -d $FF_SOURCE ]; then
    echo ""
    echo "!! ERROR"
    echo "!! Can not find FFmpeg directory for $FF_BUILD_NAME"
    echo "!! Run 'sh init-android.sh' first"
    echo ""
    exit 1
fi

#----- NDK clang toolchain (no standalone toolchain) -----
UNAME_S=$(uname -s)
FF_HOST_TAG=linux-x86_64
case "$UNAME_S" in
    Darwin)
        FF_HOST_TAG=darwin-x86_64
    ;;
esac
FF_LLVM_PREBUILT=$ANDROID_NDK/toolchains/llvm/prebuilt/$FF_HOST_TAG
FF_LLVM_BIN=$FF_LLVM_PREBUILT/bin
FF_SYSROOT=$FF_LLVM_PREBUILT/sysroot
FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output
FF_DEP_OPENSSL_INC=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_OPENSSL/output/include
FF_DEP_OPENSSL_LIB=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_OPENSSL/output/lib
FF_DEP_LIBSOXR_INC=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_LIBSOXR/output/include
FF_DEP_LIBSOXR_LIB=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_LIBSOXR/output/lib


mkdir -p $FF_PREFIX


#--------------------
echo ""
echo "--------------------"
echo "[*] check ffmpeg env"
echo "--------------------"
export PATH=$FF_LLVM_BIN:$PATH
export CC="$FF_LLVM_BIN/${FF_LLVM_TRIPLE}-clang"
export CXX="$FF_LLVM_BIN/${FF_LLVM_TRIPLE}-clang++"
export AR=$FF_LLVM_BIN/llvm-ar
export NM=$FF_LLVM_BIN/llvm-nm
export STRIP=$FF_LLVM_BIN/llvm-strip

FF_CFLAGS="-O3 -Wall -pipe \
    -ffast-math \
    -fstrict-aliasing -Werror=strict-aliasing \
    -Wa,--noexecstack \
    -DANDROID -DNDEBUG"

export COMMON_FF_CFG_FLAGS=
. $FF_BUILD_ROOT/../../config/module.sh


#--------------------
# with openssl
if [ -f "${FF_DEP_OPENSSL_LIB}/libssl.a" ]; then
    echo "OpenSSL detected"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-openssl"

    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_OPENSSL_INC}"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_OPENSSL_LIB} -lssl -lcrypto"
fi

if [ -f "${FF_DEP_LIBSOXR_LIB}/libsoxr.a" ]; then
    echo "libsoxr detected"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-libsoxr"

    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_LIBSOXR_INC}"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_LIBSOXR_LIB} -lsoxr"
fi

FF_CFG_FLAGS="$FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"

#--------------------
# Standard options:
FF_CFG_FLAGS="$FF_CFG_FLAGS --prefix=$FF_PREFIX"

# Advanced options (experts only):
FF_CFG_FLAGS="$FF_CFG_FLAGS --cross-prefix=${FF_CROSS_PREFIX}-"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cross-compile"
FF_CFG_FLAGS="$FF_CFG_FLAGS --target-os=android"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-pic"
FF_CFG_FLAGS="$FF_CFG_FLAGS --cc=$CC"
FF_CFG_FLAGS="$FF_CFG_FLAGS --cxx=$CXX"
FF_CFG_FLAGS="$FF_CFG_FLAGS --ar=$AR"
FF_CFG_FLAGS="$FF_CFG_FLAGS --nm=$NM"
FF_CFG_FLAGS="$FF_CFG_FLAGS --strip=$STRIP"
FF_CFG_FLAGS="$FF_CFG_FLAGS --sysroot=$FF_SYSROOT"
# FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-symver"

if [ "$FF_ARCH" = "x86" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-asm"
else
    # Optimization options (experts only):
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-asm"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-inline-asm"
fi

case "$FF_BUILD_OPT" in
    debug)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-small"
    ;;
    *)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-small"
    ;;
esac

# 16K page alignment (Android 15+ requirement, both ABIs)
FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -Wl,-z,max-page-size=16384"

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate ffmpeg"
echo "--------------------"
cd $FF_SOURCE
if [ -f "./config.h" ]; then
    echo 'reuse configure'
else
    which $CC
    ./configure $FF_CFG_FLAGS \
        --extra-cflags="$FF_CFLAGS $FF_EXTRA_CFLAGS" \
        --extra-ldflags="$FF_DEP_LIBS $FF_EXTRA_LDFLAGS"
    make clean
fi

#--------------------
echo ""
echo "--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"
cp config.* $FF_PREFIX
make $FF_MAKE_FLAGS > /dev/null
make install
mkdir -p $FF_PREFIX/include/libffmpeg
cp -f config.h $FF_PREFIX/include/libffmpeg/config.h

#--------------------
echo ""
echo "--------------------"
echo "[*] link ffmpeg"
echo "--------------------"
echo $FF_EXTRA_LDFLAGS

FF_C_OBJ_FILES=
FF_ASM_OBJ_FILES=
for MODULE_DIR in $FF_MODULE_DIRS
do
    C_OBJ_FILES="$MODULE_DIR/*.o"
    if ls $C_OBJ_FILES 1> /dev/null 2>&1; then
        echo "link $MODULE_DIR/*.o"
        FF_C_OBJ_FILES="$FF_C_OBJ_FILES $C_OBJ_FILES"
    fi

    for ASM_SUB_DIR in $FF_ASSEMBLER_SUB_DIRS
    do
        ASM_OBJ_FILES="$MODULE_DIR/$ASM_SUB_DIR/*.o"
        if ls $ASM_OBJ_FILES 1> /dev/null 2>&1; then
            echo "link $MODULE_DIR/$ASM_SUB_DIR/*.o"
            FF_ASM_OBJ_FILES="$FF_ASM_OBJ_FILES $ASM_OBJ_FILES"
        fi
    done
done

$CC -lm -lz -shared --sysroot=$FF_SYSROOT -Wl,--no-undefined -Wl,-z,noexecstack -Wl,-z,max-page-size=16384 $FF_EXTRA_LDFLAGS \
    -Wl,-soname,libijkffmpeg.so \
    $FF_C_OBJ_FILES \
    $FF_ASM_OBJ_FILES \
    $FF_DEP_LIBS \
    -o $FF_PREFIX/libijkffmpeg.so

mysedi() {
    f=$1
    exp=$2
    n=`basename $f`
    cp $f /tmp/$n
    sed $exp /tmp/$n > $f
    rm /tmp/$n
}

echo ""
echo "--------------------"
echo "[*] create files for shared ffmpeg"
echo "--------------------"
rm -rf $FF_PREFIX/shared
mkdir -p $FF_PREFIX/shared/lib/pkgconfig
ln -s $FF_PREFIX/include $FF_PREFIX/shared/include
ln -s $FF_PREFIX/libijkffmpeg.so $FF_PREFIX/shared/lib/libijkffmpeg.so
cp $FF_PREFIX/lib/pkgconfig/*.pc $FF_PREFIX/shared/lib/pkgconfig
for f in $FF_PREFIX/lib/pkgconfig/*.pc; do
    # in case empty dir
    if [ ! -f $f ]; then
        continue
    fi
    cp $f $FF_PREFIX/shared/lib/pkgconfig
    f=$FF_PREFIX/shared/lib/pkgconfig/`basename $f`
    # OSX sed doesn't have in-place(-i)
    mysedi $f 's/\/output/\/output\/shared/g'
    mysedi $f 's/-lavcodec/-lijkffmpeg/g'
    mysedi $f 's/-lavfilter/-lijkffmpeg/g'
    mysedi $f 's/-lavformat/-lijkffmpeg/g'
    mysedi $f 's/-lavutil/-lijkffmpeg/g'
    mysedi $f 's/-lswresample/-lijkffmpeg/g'
    mysedi $f 's/-lswscale/-lijkffmpeg/g'
done
