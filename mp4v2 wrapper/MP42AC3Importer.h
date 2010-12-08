//
//  MP42AC3FileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 07/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"

@interface MP42AC3Importer : MP42FileImporter {
    FILE* inFile;
    int64_t size;

    NSMutableData *ac3Info;
    u_int32_t samplesPerSecond;

    NSThread *dataReader;
    NSInteger readerStatus;

    NSMutableArray *samplesBuffer;
    NSMutableArray *activeTracks;

    CGFloat progress;
}

@end