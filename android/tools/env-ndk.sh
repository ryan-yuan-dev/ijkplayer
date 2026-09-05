#! /usr/bin/env bash
#
# Shared NDK detection for ijkplayer modernization (NDK r28 baseline).
# Sourced by android/contrib/tools/do-detect-env.sh and android/compile-ijk.sh.
#
# Behavior:
# - If ANDROID_NDK is set and valid, keep it.
# - Else derive from ANDROID_HOME/ndk/28.* (pick highest version).
# - Else fail with actionable message.

ijk_derive_ndk() {
    if [ -n "$ANDROID_NDK" ] && [ -d "$ANDROID_NDK" ]; then
        echo "$ANDROID_NDK"
        return 0
    fi

    if [ -z "$ANDROID_HOME" ]; then
        echo "You must define ANDROID_NDK or ANDROID_HOME before starting." 1>&2
        echo "They must point to your NDK / SDK directories." 1>&2
        return 1
    fi

    IJK_NDK_CANDIDATE=""
    if [ -d "$ANDROID_HOME/ndk" ]; then
        IJK_NDK_CANDIDATE=$(ls -d "$ANDROID_HOME"/ndk/28.* 2>/dev/null | sort -V | tail -n 1)
        if [ -z "$IJK_NDK_CANDIDATE" ]; then
            IJK_NDK_CANDIDATE=$(ls -d "$ANDROID_HOME"/ndk/29.* 2>/dev/null | sort -V | tail -n 1)
        fi
    fi

    if [ -z "$IJK_NDK_CANDIDATE" ] || [ ! -d "$IJK_NDK_CANDIDATE" ]; then
        echo "No NDK 28.* found under \$ANDROID_HOME/ndk. Set ANDROID_NDK explicitly." 1>&2
        return 1
    fi

    echo "$IJK_NDK_CANDIDATE"
    return 0
}

ANDROID_NDK=$(ijk_derive_ndk) || exit 1

# Normalize to a POSIX-style path (OpenSSL's android target matches the NDK
# path as a regex against `which` output; native Windows backslashes break it).
command -v cygpath >/dev/null 2>&1 && ANDROID_NDK=$(cygpath -u "$ANDROID_NDK")
export ANDROID_NDK
echo "ANDROID_NDK=$ANDROID_NDK"
