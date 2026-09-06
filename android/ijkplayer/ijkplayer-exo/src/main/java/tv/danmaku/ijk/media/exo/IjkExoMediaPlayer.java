/*
 * Copyright (C) 2015 Bilibili
 * Copyright (C) 2015 Zhang Rui <bbcallen@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package tv.danmaku.ijk.media.exo;

import android.content.Context;
import android.net.Uri;
import android.view.Surface;
import android.view.SurfaceHolder;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.common.VideoSize;
import androidx.media3.exoplayer.ExoPlayer;

import java.io.FileDescriptor;
import java.util.Map;

import tv.danmaku.ijk.media.player.AbstractMediaPlayer;
import tv.danmaku.ijk.media.player.IMediaPlayer;
import tv.danmaku.ijk.media.player.MediaInfo;
import tv.danmaku.ijk.media.player.misc.IjkTrackInfo;

/**
 * {@link IMediaPlayer} facade over androidx.media3 (ExoPlayer).
 *
 * M3: the former ExoPlayer r1.5 wrapper (DemoPlayer / RendererBuilders /
 * EventLogger) is replaced by media3's ExoPlayer — HLS / DASH /
 * SmoothStreaming / progressive containers are all handled by
 * DefaultMediaSourceFactory out of the box.
 */
public class IjkExoMediaPlayer extends AbstractMediaPlayer {
    private Context mAppContext;
    private ExoPlayer mInternalPlayer;
    private String mDataSource;
    private int mVideoWidth;
    private int mVideoHeight;
    private Surface mSurface;
    private boolean mLooping;

    public IjkExoMediaPlayer(Context context) {
        mAppContext = context.getApplicationContext();
        mMedia3Listener = new Media3Listener();
    }

    @Override
    public void setDisplay(SurfaceHolder sh) {
        if (sh == null)
            setSurface(null);
        else
            setSurface(sh.getSurface());
    }

    @Override
    public void setSurface(Surface surface) {
        mSurface = surface;
        if (mInternalPlayer != null)
            mInternalPlayer.setVideoSurface(surface);
    }

    @Override
    public void setDataSource(Context context, Uri uri) {
        mDataSource = uri.toString();
    }

    @Override
    public void setDataSource(Context context, Uri uri, Map<String, String> headers) {
        // TODO: handle headers
        setDataSource(context, uri);
    }

    @Override
    public void setDataSource(String path) {
        setDataSource(mAppContext, Uri.parse(path));
    }

    @Override
    public void setDataSource(FileDescriptor fd) {
        // TODO: no support
        throw new UnsupportedOperationException("no support");
    }

    @Override
    public String getDataSource() {
        return mDataSource;
    }

    @Override
    public void prepareAsync() throws IllegalStateException {
        if (mInternalPlayer != null)
            throw new IllegalStateException("can't prepare a prepared player");

        ExoPlayer.Builder builder = new ExoPlayer.Builder(mAppContext);
        mInternalPlayer = builder.build();
        mInternalPlayer.addListener(mMedia3Listener);
        mInternalPlayer.setRepeatMode(mLooping ? Player.REPEAT_MODE_ONE : Player.REPEAT_MODE_OFF);

        if (mSurface != null)
            mInternalPlayer.setVideoSurface(mSurface);

        mInternalPlayer.setMediaItem(MediaItem.fromUri(mDataSource));
        mInternalPlayer.prepare();
        mInternalPlayer.setPlayWhenReady(false);
    }

    @Override
    public void start() throws IllegalStateException {
        if (mInternalPlayer == null)
            return;
        mInternalPlayer.play();
    }

    @Override
    public void stop() throws IllegalStateException {
        if (mInternalPlayer == null)
            return;
        release();
    }

    @Override
    public void pause() throws IllegalStateException {
        if (mInternalPlayer == null)
            return;
        mInternalPlayer.pause();
    }

    @Override
    public void setWakeMode(Context context, int mode) {
        // FIXME: implement
    }

    @Override
    public void setScreenOnWhilePlaying(boolean screenOn) {
        // TODO: do nothing
    }

    @Override
    public IjkTrackInfo[] getTrackInfo() {
        // TODO: implement
        return null;
    }

    @Override
    public int getVideoWidth() {
        return mVideoWidth;
    }

    @Override
    public int getVideoHeight() {
        return mVideoHeight;
    }

    @Override
    public boolean isPlaying() {
        if (mInternalPlayer == null)
            return false;
        int state = mInternalPlayer.getPlaybackState();
        return mInternalPlayer.getPlayWhenReady()
                && (state == Player.STATE_READY || state == Player.STATE_BUFFERING);
    }

    @Override
    public void seekTo(long msec) throws IllegalStateException {
        if (mInternalPlayer == null)
            return;
        mInternalPlayer.seekTo(msec);
    }

    @Override
    public long getCurrentPosition() {
        if (mInternalPlayer == null)
            return 0;
        return mInternalPlayer.getCurrentPosition();
    }

    @Override
    public long getDuration() {
        if (mInternalPlayer == null)
            return 0;
        long duration = mInternalPlayer.getDuration();
        return duration == androidx.media3.common.C.TIME_UNSET ? 0 : duration;
    }

    @Override
    public int getVideoSarNum() {
        return 1;
    }

    @Override
    public int getVideoSarDen() {
        return 1;
    }

    @Override
    public void reset() {
        if (mInternalPlayer != null) {
            mInternalPlayer.removeListener(mMedia3Listener);
            mInternalPlayer.release();
            mInternalPlayer = null;
        }

        mSurface = null;
        mDataSource = null;
        mVideoWidth = 0;
        mVideoHeight = 0;
    }

    @Override
    public void setLooping(boolean looping) {
        mLooping = looping;
        if (mInternalPlayer != null)
            mInternalPlayer.setRepeatMode(looping ? Player.REPEAT_MODE_ONE : Player.REPEAT_MODE_OFF);
    }

    @Override
    public boolean isLooping() {
        return mLooping;
    }

    @Override
    public void setVolume(float leftVolume, float rightVolume) {
        if (mInternalPlayer == null)
            return;
        mInternalPlayer.setVolume((leftVolume + rightVolume) / 2);
    }

    @Override
    public int getAudioSessionId() {
        if (mInternalPlayer == null)
            return 0;
        return mInternalPlayer.getAudioSessionId();
    }

    @Override
    public MediaInfo getMediaInfo() {
        // TODO: no support
        return null;
    }

    @Override
    public void setLogEnabled(boolean enable) {
        // do nothing
    }

    @Override
    public boolean isPlayable() {
        return true;
    }

    @Override
    public void setAudioStreamType(int streamtype) {
        // do nothing
    }

    @Override
    public void setKeepInBackground(boolean keepInBackground) {
        // do nothing
    }

    @Override
    public void release() {
        if (mInternalPlayer != null) {
            mInternalPlayer.removeListener(mMedia3Listener);
            mInternalPlayer.release();
            mInternalPlayer = null;
        }
    }

    public int getBufferedPercentage() {
        if (mInternalPlayer == null)
            return 0;

        return (int) (mInternalPlayer.getBufferedPercentage() * 100);
    }

    private class Media3Listener implements Player.Listener {
        private boolean mIsPreparing = false;
        private boolean mIsBuffering = false;

        @Override
        public void onPlaybackStateChanged(int playbackState) {
            if (mIsBuffering) {
                switch (playbackState) {
                    case Player.STATE_ENDED:
                    case Player.STATE_READY:
                        notifyOnInfo(IMediaPlayer.MEDIA_INFO_BUFFERING_END, getBufferedPercentage());
                        mIsBuffering = false;
                        break;
                }
            }

            if (mIsPreparing) {
                switch (playbackState) {
                    case Player.STATE_READY:
                        notifyOnPrepared();
                        mIsPreparing = false;
                        break;
                }
            }

            switch (playbackState) {
                case Player.STATE_IDLE:
                    notifyOnCompletion();
                    break;
                case Player.STATE_BUFFERING:
                    notifyOnInfo(IMediaPlayer.MEDIA_INFO_BUFFERING_START, getBufferedPercentage());
                    mIsBuffering = true;
                    break;
                case Player.STATE_ENDED:
                    notifyOnCompletion();
                    break;
                default:
                    break;
            }
        }

        @Override
        public void onPlayerError(@NonNull androidx.media3.common.PlaybackException error) {
            notifyOnError(IMediaPlayer.MEDIA_ERROR_UNKNOWN, IMediaPlayer.MEDIA_ERROR_UNKNOWN);
        }

        @Override
        public void onVideoSizeChanged(@NonNull VideoSize videoSize) {
            mVideoWidth = videoSize.width;
            mVideoHeight = videoSize.height;
            notifyOnVideoSizeChanged(videoSize.width, videoSize.height, 1, 1);
            if (videoSize.unappliedRotationDegrees > 0)
                notifyOnInfo(IMediaPlayer.MEDIA_INFO_VIDEO_ROTATION_CHANGED, videoSize.unappliedRotationDegrees);
        }

        @Override
        public void onEvents(@Nullable Player player, androidx.media3.common.Player.Events events) {
            // no-op; state transitions are handled above
        }
    }

    private Media3Listener mMedia3Listener;
}
