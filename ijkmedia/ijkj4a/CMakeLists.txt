add_library(ijkj4a STATIC
    j4a/j4a_allclasses.c
    j4a/j4a_base.c
    j4a/class/android/media/AudioTrack.c
    j4a/class/android/media/MediaCodec.c
    j4a/class/android/media/MediaFormat.c
    j4a/class/android/media/PlaybackParams.c
    j4a/class/android/os/Build.c
    j4a/class/android/os/Bundle.c
    j4a/class/java/nio/Buffer.c
    j4a/class/java/nio/ByteBuffer.c
    j4a/class/java/util/ArrayList.c
    j4a/class/tv/danmaku/ijk/media/player/misc/IMediaDataSource.c
    j4a/class/tv/danmaku/ijk/media/player/misc/IAndroidIO.c
    j4a/class/tv/danmaku/ijk/media/player/IjkMediaPlayer.c
    j4au/class/android/media/AudioTrack.util.c
    j4au/class/java/nio/ByteBuffer.util.c
)

target_include_directories(ijkj4a PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
