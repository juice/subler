//
//  MP42Sample.m
//  Subler
//
//  Created by Damiano Galassi on 29/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "MP42Sample.h"


@implementation MP42SampleBuffer

-(void) dealloc {
    free(sampleData);
    [super dealloc];
}

@synthesize  sampleData;
@synthesize  sampleSize;
@synthesize  sampleDuration;
@synthesize  sampleOffset;
@synthesize  sampleTimestamp;
@synthesize  sampleTrackId;
@synthesize  sampleIsSync;
@synthesize  sampleSourceTrack;

@end
