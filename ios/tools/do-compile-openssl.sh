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

# Modernized for OpenSSL 3.5 LTS (xcrun targets, iOS 13 baseline,
# arm64 / arm64-sim / x86_64-sim only).

#--------------------
echo "===================="
echo "[*] check host"
echo "===================="
set -e

FF_XCRUN_DEVELOPER=`xcode-select -print-path`
if [ ! -d "$FF_XCRUN_DEVELOPER" ]; then
  echo "xcode path is not set correctly $FF_XCRUN_DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

#--------------------
# common defines
FF_ARCH=$1
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm64, arm64-sim, x86_64-sim'.\n"
    exit 1
fi

FF_BUILD_ROOT=`pwd`
FF_MIN_IOS_VERSION=13.0

FF_BUILD_NAME=
FF_XCRUN_PLATFORM=
FF_OSVERSION_FLAG=
FF_TARGET_ARCH=

echo "build_root: $FF_BUILD_ROOT"

#--------------------
echo "===================="
echo "[*] config arch $FF_ARCH"
echo "===================="

if [ "$FF_ARCH" = "arm64" ]; then
    FF_BUILD_NAME="openssl-arm64"
    FF_XCRUN_PLATFORM="iPhoneOS"
    FF_OSVERSION_FLAG="-miphoneos-version-min=$FF_MIN_IOS_VERSION"
    FF_TARGET_ARCH=ios64-xcrun
elif [ "$FF_ARCH" = "arm64-sim" ]; then
    FF_BUILD_NAME="openssl-arm64-sim"
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_OSVERSION_FLAG="-mios-simulator-version-min=$FF_MIN_IOS_VERSION"
    FF_TARGET_ARCH=iossimulator-arm64-xcrun
elif [ "$FF_ARCH" = "x86_64-sim" ]; then
    FF_BUILD_NAME="openssl-x86_64-sim"
    FF_XCRUN_PLATFORM="iPhoneSimulator"
    FF_OSVERSION_FLAG="-mios-simulator-version-min=$FF_MIN_IOS_VERSION"
    FF_TARGET_ARCH=iossimulator-x86_64-xcrun
else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

echo "build_name: $FF_BUILD_NAME"
echo "platform:   $FF_XCRUN_PLATFORM"
echo "osversion:  $FF_OSVERSION_FLAG"

#--------------------
echo "===================="
echo "[*] make ios toolchain $FF_BUILD_NAME"
echo "===================="

FF_BUILD_SOURCE="$FF_BUILD_ROOT/$FF_BUILD_NAME"
FF_BUILD_PREFIX="$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output"

mkdir -p $FF_BUILD_PREFIX

FF_XCRUN_SDK=`echo $FF_XCRUN_PLATFORM | tr '[:upper:]' '[:lower:]'`
export CC="xcrun -sdk $FF_XCRUN_SDK clang"

echo "build_source: $FF_BUILD_SOURCE"
echo "build_prefix: $FF_BUILD_PREFIX"
echo "CC: $CC"

#--------------------
echo "\n--------------------"
echo "[*] configurate openssl"
echo "--------------------"

OPENSSL_CFG_FLAGS="no-shared"
OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS no-tests"
OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS --prefix=$FF_BUILD_PREFIX"
OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS --libdir=lib"
OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS --openssldir=$FF_BUILD_PREFIX"
OPENSSL_CFG_FLAGS="$OPENSSL_CFG_FLAGS $FF_OSVERSION_FLAG"

# xcode configuration
export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

cd $FF_BUILD_SOURCE
if [ -f "./Makefile" ] && [ -f "./configdata.pm" ]; then
    echo 'reuse configure'
else
    echo "config: $FF_TARGET_ARCH $OPENSSL_CFG_FLAGS"
    ./Configure $FF_TARGET_ARCH $OPENSSL_CFG_FLAGS
fi

#--------------------
echo "\n--------------------"
echo "[*] compile openssl"
echo "--------------------"
make
make install_sw
