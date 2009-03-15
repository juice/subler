//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "SubMuxer.h"
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
        if ([[sourcePath pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
            success = muxSRTSubtitleTrack(fileHandle,
                                          sourcePath,
                                          lang_for_english([language UTF8String])->iso639_2,
                                          trackHeight,
                                          delay);
        else if ([[sourcePath pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
                 [[sourcePath pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame)
            success = muxMP4SubtitleTrack(fileHandle,
                                          sourcePath,
                                          sourceId);

        if (!success && (outError != NULL)) {
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
