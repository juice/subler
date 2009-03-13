//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "MP42Utilities.h"
#import "SubUtilities.h"
#import "lang.h"

int muxSubtitleTrack(MP4FileHandle fileHandle, NSString* subtitlePath, const char* lang, uint16_t subtitleHeight, int16_t delay);

@implementation MP42SubtitleTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", &height);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", &width);
    }

    return self;
}

-(id) init
{
    if (self = [super init])
    {
        name = @"Subtitle Track";
        format = @"3GPP Text";
    }

    return self;
}

- (id) initWithSubtitleFile:(NSString *)filePath
                      delay:(int)subDelay
                     height:(unsigned int)subHeight
                   language:(NSString *)subLanguage
{
    if (self = [super init])
    {
        name = @"Subtitle Track";
        format = @"3GPP Text";
        sourcePath = [filePath retain];
        delay = subDelay;
        height = subHeight;
        if (!subLanguage)
            language = @"English";
        else
            language = [subLanguage retain];
        isEdited = YES;
        isDataEdited = YES;
        muxed = NO;
    }

    return self;
}

+ (id) subtitleTrackFromFile:(NSString *)filePath
                       delay:(int)subDelay
                      height:(unsigned int)subHeight
                    language:(NSString *)subLanguage
{
    return [[[MP42SubtitleTrack alloc] initWithSubtitleFile:filePath
                                                      delay:subDelay
                                                     height:subHeight
                                                   language:subLanguage] autorelease];
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL success = YES;

    if (isEdited && !muxed)
    {
        success = muxSubtitleTrack(fileHandle,
                               sourcePath,
                               lang_for_english([language UTF8String])->iso639_2,
                               height,
                               delay);
    
        if ((!success) && (outError != NULL)) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Failed to mux subtitles into mp4 file" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:110
                                        userInfo:errorDetail];
        }

        return success;
    }
    else
        [super writeToFile:fileHandle error:outError];

    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", trackHeight);
    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", trackWidth);

    return YES;
}

- (void) dealloc
{
    [super dealloc];
}

@synthesize delay;

@end

MP4TrackId createSubtitleTrack(MP4FileHandle file, MP4TrackId refTrackId, const char* language_iso639_2,
                               uint16_t video_width, uint16_t video_height, uint16_t subtitleHeight)
{
    const uint8_t textColor[4] = { 255,255,255,255 };
    MP4TrackId subtitle_track = MP4AddSubtitleTrack(file, refTrackId);

    MP4SetTrackLanguage(file, subtitle_track, language_iso639_2);

    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.width", video_width);
    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.height", subtitleHeight);

    MP4SetTrackIntegerProperty(file,subtitle_track, "tkhd.alternate_group", 2);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.verticalJustification", 0);

	MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", subtitleHeight);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", video_width);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontID", 1);
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

    MP4GetTrackBytesProperty(file, subtitle_track, "tkhd.matrix", &val, &size);
    memcpy(nval, val, size);
    ptr32[7] = CFSwapInt32HostToBig( (video_height - subtitleHeight) * 0x10000);

    MP4SetTrackBytesProperty(file, subtitle_track, "tkhd.matrix", nval, size);
    free(val);

    /* set the timescale to ms */
    MP4SetTrackTimeScale(file,subtitle_track, 1000);

    enableFirstSubtitleTrack(file);

	return subtitle_track;
}

int writeSubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId,const char* string, MP4Duration duration)
{
    int Err;
    const size_t stringLength = strlen(string);
    u_int8_t buffer[1024];
    memcpy(buffer+2, string, strlen(string)); // strlen > 1024 -> booom?
    buffer[0] = (stringLength >> 8) & 0xff;
    buffer[1] = stringLength & 0xff;
    
    Err = MP4WriteSample(file,
                         subtitleTrackId,
                         buffer,
                         stringLength + 2,
                         duration,
                         0, true);
    return Err;
}

int writeEmptySubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId, MP4Duration duration)
{
    int Err;
    u_int8_t empty[2] = {0,0};
    Err = MP4WriteSample(file,
                         subtitleTrackId,
                         empty,
                         2,
                         duration,
                         0, true);
    return Err;
}

int muxSubtitleTrack(MP4FileHandle fileHandle, NSString* subtitlePath, const char* lang, uint16_t subtitleHeight, int16_t delay) {
    BOOL success = YES;
    MP4TrackId subtitleTrackId, videoTrack;
    uint16_t videoWidth, videoHeight;

    videoTrack = findFirstVideoTrack(fileHandle);
    if (!videoTrack)
        return 0;

    videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
    videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    SubSerializer *ss = [[SubSerializer alloc] init];
    success = LoadSRTFromPath(subtitlePath, ss);
    [ss setFinished:YES];

    if (success) {
        int firstSub = 0;

        success = subtitleTrackId = createSubtitleTrack(fileHandle, 1, lang, videoWidth, videoHeight, subtitleHeight);

        while (![ss isEmpty]) {
            SubLine *sl = [ss getSerializedPacket];
            const char *str = [sl->line UTF8String];
            if (firstSub == 0) {
                firstSub++;
                if (!writeEmptySubtitleSample(fileHandle, subtitleTrackId, sl->begin_time + delay))
                    break;
            }
            if ([sl->line isEqualToString:@"\n"]) {
                if (!writeEmptySubtitleSample(fileHandle, subtitleTrackId, sl->end_time - sl->begin_time))
                    break;
                continue;
            }
            if (!writeSubtitleSample(fileHandle, subtitleTrackId, str, sl->end_time - sl->begin_time))
                break;
        }
        writeEmptySubtitleSample(fileHandle, subtitleTrackId, 100);
    }

    [ss release];
    [pool release];

    return success;
}
