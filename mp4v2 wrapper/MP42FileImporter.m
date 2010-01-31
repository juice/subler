//
//  MP42FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MP42FileImporter.h"


@implementation MP42FileImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if (self = [super init]) {
        delegate = del;
        file = [fileUrl retain];
    }

    return self;
}

@synthesize tracksArray;

@end