#! /usr/bin/env bash
#
# Copyright (C) 2014 Miguel Botón <waninkoko@gmail.com>
# Copyright (C) 2014 Zhang Rui <bbcallen@gmail.com>
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

# Modernized for OpenSSL 3.5 LTS + NDK r28 (clang-only, arm64/x86_64 only).

#--------------------
set -e

FF_ARCH=$1
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm64, x86_64'.\n"
    exit 1
fi

FF_BUILD_ROOT=`pwd`
FF_ANDROID_API=24

FF_BUILD_NAME=
FF_SOURCE=
FF_CFG_FLAGS=

#--------------------
echo ""
echo "--------------------"
echo "[*] check NDK env"
echo "--------------------"
. ./tools/do-detect-env.sh
FF_MAKE_FLAGS=$IJK_MAKE_FLAG

#----- arch begin -----
if [ "$FF_ARCH" = "x86_64" ]; then
    FF_BUILD_NAME=openssl-x86_64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME
    FF_TARGET_ARCH=android-x86_64
elif [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME=openssl-arm64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME
    FF_TARGET_ARCH=android-arm64
else
    echo "unknown architecture $FF_ARCH (only arm64/x86_64 supported)";
    exit 1
fi

FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output
mkdir -p $FF_PREFIX

#--------------------
echo ""
echo "--------------------"
echo "[*] check openssl env"
echo "--------------------"
UNAME_S=$(uname -s)
FF_HOST_TAG=linux-x86_64
case "$UNAME_S" in
    Darwin)
        FF_HOST_TAG=darwin-x86_64
    ;;
    MINGW*|MSYS*|CYGWIN*)
        FF_HOST_TAG=windows-x86_64
    ;;
esac
FF_LLVM_PREBUILT=$ANDROID_NDK/toolchains/llvm/prebuilt/$FF_HOST_TAG
FF_LLVM_BIN=$FF_LLVM_PREBUILT/bin

export PATH=$FF_LLVM_BIN:$PATH
# OpenSSL 3.x android targets locate the NDK through ANDROID_NDK_ROOT.
export ANDROID_NDK_ROOT=$ANDROID_NDK

FF_CFG_FLAGS="$FF_CFG_FLAGS no-shared"
FF_CFG_FLAGS="$FF_CFG_FLAGS no-tests"
FF_CFG_FLAGS="$FF_CFG_FLAGS zlib-dynamic"
FF_CFG_FLAGS="$FF_CFG_FLAGS --prefix=$FF_PREFIX"
FF_CFG_FLAGS="$FF_CFG_FLAGS --libdir=lib"
FF_CFG_FLAGS="$FF_CFG_FLAGS --openssldir=$FF_PREFIX"
FF_CFG_FLAGS="$FF_CFG_FLAGS -D__ANDROID_API__=$FF_ANDROID_API"

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate openssl ($FF_TARGET_ARCH)"
echo "--------------------"
cd $FF_SOURCE
if [ -f "./Makefile" ] && [ -f "./configdata.pm" ]; then
    echo 'reuse configure'
else
    echo "./Configure $FF_TARGET_ARCH $FF_CFG_FLAGS"
    ./Configure $FF_TARGET_ARCH $FF_CFG_FLAGS
fi

#--------------------
echo ""
echo "--------------------"
echo "[*] compile openssl"
echo "--------------------"
make $FF_MAKE_FLAGS
make install_sw
