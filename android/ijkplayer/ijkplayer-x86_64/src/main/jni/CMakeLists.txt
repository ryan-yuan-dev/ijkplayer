# Modernized native build (CMake) for ijkplayer — replaces the former ndk-build
# jni/Android.mk + Application.mk chain (M2).
#
# Driven by android/compile-ijk.sh, and later by the Gradle modules via
# externalNativeBuild. Consumes the prebuilt libijkffmpeg.so produced by
# android/contrib/compile-ffmpeg.sh.
#
# Note: ijkyuv/ and ijksoundtouch/ are vendored Bilibili forks pulled by
# init-android-libyuv.sh / init-android-soundtouch.sh into <repo>/ijkmedia
# (gitignored), so their targets are defined here instead of inside them.
cmake_minimum_required(VERSION 3.22)
project(ijkplayer LANGUAGES C CXX)

set(IJK_JNI_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
# jni -> main -> src -> ijkplayer-<abi> -> ijkplayer -> android
set(IJK_ANDROID_ROOT ${IJK_JNI_ROOT}/../../../../..)
# jni -> main -> src -> ijkplayer-<abi> -> ijkplayer -> android -> <repo root>
get_filename_component(IJK_REPO_ROOT ${IJK_ANDROID_ROOT}/.. ABSOLUTE)

# Parity with the former Application.mk
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
add_compile_options(
    -Wall
    -pipe
    -ffast-math
    -fstrict-aliasing
    -Werror=strict-aliasing
    -Wno-psabi
)

if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(IJK_FFMPEG_OUTPUT ${IJK_ANDROID_ROOT}/contrib/build/ffmpeg-arm64/output)
    set(IJK_LIBYUV_NEON ON)
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(IJK_FFMPEG_OUTPUT ${IJK_ANDROID_ROOT}/contrib/build/ffmpeg-x86_64/output)
else()
    message(FATAL_ERROR "unsupported ANDROID_ABI ${ANDROID_ABI} (only arm64-v8a/x86_64)")
endif()

if(NOT EXISTS ${IJK_FFMPEG_OUTPUT}/libijkffmpeg.so)
    message(FATAL_ERROR "libijkffmpeg.so not found under ${IJK_FFMPEG_OUTPUT}; run android/contrib/compile-ffmpeg.sh first")
endif()
set(IJK_FFMPEG_INCLUDE_PATH ${IJK_FFMPEG_OUTPUT}/include)

add_library(ijkffmpeg SHARED IMPORTED)
set_target_properties(ijkffmpeg PROPERTIES
    IMPORTED_LOCATION ${IJK_FFMPEG_OUTPUT}/libijkffmpeg.so
    IMPORTED_SONAME libijkffmpeg.so)

# ndk-build used to import these from the NDK sources; do the same here.
add_library(cpufeatures STATIC ${ANDROID_NDK}/sources/android/cpufeatures/cpu-features.c)
target_include_directories(cpufeatures PUBLIC ${ANDROID_NDK}/sources/android/cpufeatures)

# profiler: ijkprof/android-ndk-profiler-dummy (same no-op stub the ndk-build
# build linked through the android-ndk-prof symlink)
set(IJK_PROFILER_DIR ${IJK_REPO_ROOT}/ijkprof/android-ndk-profiler-dummy/jni)
add_library(android-ndk-profiler STATIC ${IJK_PROFILER_DIR}/prof.c)
target_include_directories(android-ndk-profiler PRIVATE ${IJK_PROFILER_DIR})

# ijkmedia is a symlink (NTFS junction on Windows) to <repo root>/ijkmedia
set(IJKMEDIA_DIR ${IJK_JNI_ROOT}/ijkmedia)

# ---- vendored libyuv (Bilibili fork) ----
add_library(yuv_static STATIC
    ${IJKMEDIA_DIR}/ijkyuv/source/compare.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/compare_common.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/compare_posix.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert_argb.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert_from.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert_from_argb.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert_to_argb.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/convert_to_i420.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/cpu_id.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/format_conversion.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/planar_functions.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/rotate.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/rotate_argb.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/rotate_mips.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/row_any.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/row_common.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/row_mips.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/row_posix.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/scale.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/scale_argb.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/scale_common.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/scale_mips.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/scale_posix.cc
    ${IJKMEDIA_DIR}/ijkyuv/source/video_common.cc
)
if(IJK_LIBYUV_NEON)
    target_compile_definitions(yuv_static PRIVATE LIBYUV_NEON)
    target_sources(yuv_static PRIVATE
        ${IJKMEDIA_DIR}/ijkyuv/source/compare_neon64.cc
        ${IJKMEDIA_DIR}/ijkyuv/source/rotate_neon64.cc
        ${IJKMEDIA_DIR}/ijkyuv/source/row_neon64.cc
        ${IJKMEDIA_DIR}/ijkyuv/source/scale_neon64.cc
    )
endif()
target_include_directories(yuv_static PUBLIC ${IJKMEDIA_DIR}/ijkyuv/include)

# ---- vendored soundtouch (Bilibili fork) ----
add_library(ijksoundtouch STATIC
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/AAFilter.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/FIFOSampleBuffer.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/FIRFilter.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/cpu_detect_x86.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/sse_optimized.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/RateTransposer.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/InterpolateCubic.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/InterpolateLinear.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/InterpolateShannon.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/TDStretch.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/BPMDetect.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/PeakFinder.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/SoundTouch.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/source/SoundTouch/mmx_optimized.cpp
    ${IJKMEDIA_DIR}/ijksoundtouch/ijksoundtouch_wrap.cpp
)
target_include_directories(ijksoundtouch PUBLIC
    ${IJKMEDIA_DIR}/ijksoundtouch
    ${IJKMEDIA_DIR}/ijksoundtouch/..
    ${IJKMEDIA_DIR}/ijksoundtouch/include
)

add_subdirectory(${IJKMEDIA_DIR}/ijkj4a ${CMAKE_BINARY_DIR}/ijkj4a)
add_subdirectory(${IJKMEDIA_DIR}/ijksdl ${CMAKE_BINARY_DIR}/ijksdl)
add_subdirectory(${IJKMEDIA_DIR}/ijkplayer ${CMAKE_BINARY_DIR}/ijkplayer)
