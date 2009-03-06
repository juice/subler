//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42VideoTrack.h"

@implementation MP42VideoTrack

-(id) init
{
    if (self = [super init])
    {
        name = @"Video Track";
    }

    return self;
}

- (void) dealloc
{
    [super dealloc];
}

@synthesize width;
@synthesize height;

@end
