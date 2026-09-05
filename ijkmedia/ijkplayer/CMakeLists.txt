# ijkversion.h is generated from the git revision; compile-ijk.sh pre-generates
# it, and this hook keeps it fresh when sh is available.
find_program(IJK_SH sh)
if(IJK_SH)
    execute_process(
        COMMAND ${IJK_SH} ${CMAKE_CURRENT_SOURCE_DIR}/version.sh
                ${CMAKE_CURRENT_SOURCE_DIR} ijkversion.h
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        OUTPUT_QUIET ERROR_QUIET
    )
endif()

add_library(ijkplayer SHARED
    ff_cmdutils.c
    ff_ffplay.c
    ff_ffpipeline.c
    ff_ffpipenode.c
    ijkmeta.c
    ijkplayer.c
    pipeline/ffpipeline_ffplay.c
    pipeline/ffpipenode_ffplay_vdec.c
    android/ffmpeg_api_jni.c
    android/ijkplayer_android.c
    android/ijkplayer_jni.c
    android/pipeline/ffpipeline_android.c
    android/pipeline/ffpipenode_android_mediacodec_vdec.c
    ijkavformat/allformats.c
    ijkavformat/cJSON.c
    # n7.1: ijklas/ijklivehook define FFInputFormat (libavformat/demux.h,
    # installed by patches-ffmpeg7) and overwrite the dummy demuxer slots in
    # libijkffmpeg at startup via ijkav_register_ijk_demuxers().
    ijkavformat/ijklas.c
    ijkavformat/ijklivehook.c
    ijkavformat/ijkmediadatasource.c
    ijkavformat/ijkio.c
    ijkavformat/ijkiomanager.c
    ijkavformat/ijkiocache.c
    ijkavformat/ijkioffio.c
    ijkavformat/ijkioandroidio.c
    ijkavformat/ijkioprotocol.c
    ijkavformat/ijkioapplication.c
    ijkavformat/ijkiourlhook.c
    ijkavformat/ijkasync.c
    ijkavformat/ijkurlhook.c
    ijkavformat/ijklongurl.c
    ijkavformat/ijksegment.c
    ijkavutil/ijkdict.c
    ijkavutil/ijkutils.c
    ijkavutil/ijkthreadpool.c
    ijkavutil/ijktree.c
    ijkavutil/ijkfifo.c
    ijkavutil/ijkstl.cpp
)

target_include_directories(ijkplayer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${IJK_FFMPEG_INCLUDE_PATH}
    ${CMAKE_CURRENT_SOURCE_DIR}/../ijkj4a
)

target_link_libraries(ijkplayer
    PRIVATE
        ijksdl
        ijkffmpeg
        android-ndk-profiler
        ijksoundtouch
        log
        android
)
