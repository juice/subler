//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "SubMuxer.h"
#import "MP42Utilities.h"
#import "lang.h"

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
        trackHeight = subHeight;
        if (!subLanguage)
            [self setLanguage: @"English"];
        else
            [self setLanguage: subLanguage];
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
    if (isEdited && !muxed)
    {
        if ([[sourcePath pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame) {
            Id = muxSRTSubtitleTrack(fileHandle,
                                          sourcePath,
                                          trackHeight,
                                          delay);
        }
        else if ([sourceInputType isEqualToString:MP42SourceTypeMP4])
            Id = muxMP4SubtitleTrack(fileHandle, sourcePath, sourceId);
        else if ([sourceInputType isEqualToString:MP42SourceTypeQuickTime]) {
#if !__LP64__
            Id = muxMOVSubtitleTrack(fileHandle, sourceFileHandle, sourceId);
#endif
        }

        if (!Id && (outError != NULL)) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Failed to mux subtitles into mp4 file" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:110
                                        userInfo:errorDetail];
        }
        muxed = YES;
        enableFirstSubtitleTrack(fileHandle);

        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.width", &trackWidth);
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.height", &trackHeight);

        uint8_t *val;
        uint8_t nval[36];
        uint32_t *ptr32 = (uint32_t*) nval;
        uint32_t size;

        MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
        memcpy(nval, val, size);
        offsetX = CFSwapInt32BigToHost(ptr32[6]) / 0x10000;
        offsetY = CFSwapInt32BigToHost(ptr32[7]) / 0x10000;
        free(val);

        [super writeToFile:fileHandle error:outError];
        return Id;
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
