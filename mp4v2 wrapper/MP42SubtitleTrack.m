//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42SubtitleTrack.h"

@implementation MP42SubtitleTrack

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

- (void) dealloc
{
    [super dealloc];
}

@synthesize delay;

@end
