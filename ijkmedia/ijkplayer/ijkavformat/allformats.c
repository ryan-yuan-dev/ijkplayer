/*
 * Copyright (c) 2003 Bilibili
 * Copyright (c) 2003 Fabrice Bellard
 * Copyright (c) 2015 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 * Based on libavformat/allformats.c
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "libavformat/avformat.h"
#include "libavformat/url.h"
#include "libavformat/version.h"

/* n7.1: ijk custom protocols/demuxers register in FFmpeg tree via
 * android/patches-ffmpeg7/ (R1). This translation unit keeps
 * ijkav_register_all() as a no-op marker so call sites stay unchanged. */

void ijkav_register_all(void)
{
    static int initialized;

    if (initialized)
        return;
    initialized = 1;

    /* n7.1: av_register_all() removed (static registration). No-op. */
    av_log(NULL, AV_LOG_INFO, "ijkav_register_all: custom modules register via patches-ffmpeg7 (R1)\n");
}
