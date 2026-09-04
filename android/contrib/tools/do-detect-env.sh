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

# Modernized for NDK r28 (clang-only, no gcc/standalone toolchain).

#--------------------
set -e

UNAME_S=$(uname -s)
UNAME_SM=$(uname -sm)
echo "build on $UNAME_SM"

# Shared derivation: ANDROID_NDK explicit > ANDROID_HOME/ndk/28.* (highest).
IJK_ENV_NDK_SH="$(dirname "$0")/../../tools/env-ndk.sh"
if [ -f "$IJK_ENV_NDK_SH" ]; then
    . "$IJK_ENV_NDK_SH"
fi

echo "ANDROID_NDK=$ANDROID_NDK"

if [ -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK (or ANDROID_HOME with ndk/28.*) before starting."
    echo ""
    exit 1
fi

# try to detect NDK version (r28 baseline, clang-only)
export IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $ANDROID_NDK/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
echo "IJK_NDK_REL=$IJK_NDK_REL"
case "$IJK_NDK_REL" in
    28*)
        echo "NDKr$IJK_NDK_REL detected"
    ;;
    *)
        echo "You need NDK r28 (28.*). Set ANDROID_NDK to an r28 install."
        exit 1
    ;;
esac

# parallel build flag
export IJK_MAKE_FLAG=
case "$UNAME_S" in
    Darwin)
        export IJK_MAKE_FLAG=-j`sysctl -n machdep.cpu.thread_count`
    ;;
esac
