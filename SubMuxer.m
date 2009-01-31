//
//  SubMuxer.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SubMuxer.h"
#include "mp4v2/mp4v2.h"

@implementation SubMuxer

MP4TrackId createSubtitleTrack(MP4FileHandle file, MP4TrackId refTrackId, const char* language_iso639_2, uint16_t video_width, uint16_t video_height, uint16_t subtitleHeight)
{
    const uint8_t textColor[4] = { 255,255,255,255 };
    int i;
    MP4TrackId subtitle_track = MP4AddSubtitleTrack(file, refTrackId);

    MP4SetTrackLanguage(file, subtitle_track, language_iso639_2);

    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.width", video_width);
    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.height", subtitleHeight);

    MP4SetTrackIntegerProperty(file,subtitle_track, "tkhd.alternate_group", 2);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.verticalJustification", 0);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.verticalJustification", 0);

	MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", subtitleHeight);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", video_width);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontSize", 24);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorRed", textColor[0]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", textColor[1]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", textColor[2]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", textColor[3]);

    /* translate the track */
    uint8_t* val;
    uint8_t nval[36];
    uint32_t *ptr32 = (uint32_t*) nval;
    uint32_t size;
    MP4GetTrackBytesProperty(file,subtitle_track, "tkhd.matrix", &val, &size);

    memcpy(nval, val, size);

    ptr32[7] = CFSwapInt32HostToBig( (video_height - subtitleHeight) * 0x10000 );

    MP4SetTrackBytesProperty(file,subtitle_track, "tkhd.matrix", nval, size);    

    /* set the timescale to ms */
    MP4SetTrackTimeScale(file,subtitle_track, 1000);

    MP4TrackId firstTrack = 0;
    /* enable only the first subtitle track */
    for(i = 0; i < MP4GetNumberOfTracks( file, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( file, MP4FindTrackId( file, i, 0, 0));

        if(!strcmp(trackType, "sbtl")) {
            if (firstTrack++ == 0)
                MP4SetTrackIntegerProperty(file, MP4FindTrackId( file, i, 0, 0), "tkhd.flags", (TRACK_ENABLED | TRACK_IN_MOVIE));
            else
                MP4SetTrackIntegerProperty(file, subtitle_track, "tkhd.flags", (TRACK_DISABLED | TRACK_IN_MOVIE));
        }
    }

	return subtitle_track;
}

int writeSubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId,const char* string, MP4Duration duration, MP4Duration offset)
{
    const size_t stringLength = strlen(string);
    u_int8_t buffer[1024];
    int Err;
    memcpy(buffer+2, string, strlen(string)); // strlen > 1024 -> booom?
    buffer[0] = (stringLength >> 8) & 0xff;
    buffer[1] = stringLength & 0xff;

    if(offset) {
        u_int8_t empty[2] = {0,0};
        Err = MP4WriteSample(file,
                             subtitleTrackId,
                             empty,
                             2,
                             offset,
                             0, true);
    }
    else if(duration) {
    Err = MP4WriteSample(file,
                         subtitleTrackId,
                         buffer,
                         stringLength + 2,
                         duration,
                         0, true);
    }
    return Err;
}

int muxSubtitleTrack(NSString* filePath, NSString* subtitlePath, const char* lang, uint16_t subtitleHeight, int16_t delay) {
    MP4FileHandle fileHandle;
    MP4TrackId subtitleTrackId;
    int trackNumber, i, videoTrack, videoWidth, videoHeight;
    uint64_t hSpacing, vSpacing;

    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return 0;
    }

    trackNumber = MP4GetNumberOfTracks( fileHandle, 0, 0);
    for (i = 0; i <= trackNumber; i++) {
        videoTrack = MP4FindTrackId( fileHandle, i, 0, 0);
        const char* trackType = MP4GetTrackType( fileHandle, videoTrack);
        if (!strcmp(trackType, MP4_VIDEO_TRACK_TYPE))
            break;
    }

    videoWidth = MP4GetTrackVideoWidth(fileHandle, videoTrack);
    videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);

    const char *format = MP4GetTrackMediaDataName(fileHandle, videoTrack);

    if (!strcasecmp(format, "avc1"))
        if(MP4GetTrackIntegerProperty(fileHandle, videoTrack, "mdia.minf.stbl.stsd.avc1.pasp.hSpacing", &hSpacing) &&
            MP4GetTrackIntegerProperty(fileHandle, videoTrack, "mdia.minf.stbl.stsd.avc1.pasp.vSpacing", &vSpacing) )
            videoWidth = (float) videoWidth / vSpacing * hSpacing;

    else if (!strcasecmp(format, "mp4v"))
        if(MP4GetTrackIntegerProperty(fileHandle, videoTrack, "mdia.minf.stbl.stsd.mp4v.pasp.hSpacing", &hSpacing) &&
           MP4GetTrackIntegerProperty(fileHandle, videoTrack, "mdia.minf.stbl.stsd.mp4v.pasp.vSpacing", &vSpacing) )
            videoWidth = (float) videoWidth / vSpacing * hSpacing;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    SubSerializer *ss = [[SubSerializer alloc] init];
    LoadSRTFromPath(subtitlePath, ss);
    [ss setFinished:YES];

    subtitleTrackId = createSubtitleTrack( fileHandle, 1, lang, videoWidth, videoHeight, subtitleHeight );
    NSLog(@"lalala");
    i = 0;
    while (![ss isEmpty]) {
		SubLine *sl = [ss getSerializedPacket];
        NSLog(@"begin: %d, end: %d", sl->begin_time, sl->end_time);
		const char *str = [sl->line UTF8String];
        if (i == 0) {
            i++;
            writeSubtitleSample(fileHandle, subtitleTrackId, str, 0, sl->begin_time + delay);
        }
        if ([sl->line isEqualToString:@"\n"])
        {
            writeSubtitleSample(fileHandle, subtitleTrackId, str, 0, sl->end_time - sl->begin_time);
            continue;
        }
        writeSubtitleSample(fileHandle, subtitleTrackId, str, sl->end_time - sl->begin_time, 0);
	}

    writeSubtitleSample(fileHandle, subtitleTrackId, " ", 0, 100);

    [ss release];
    [pool release];

    MP4Close(fileHandle);

    return 0;
}

@end
