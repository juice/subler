//
//  MP42MkvFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"
#import "mp4v2.h"

@interface MP42Mp4Importer : MP42FileImporter {
    MP4FileHandle  fileHandle;

    NSThread *dataReader;
    NSInteger readerStatus;

    NSMutableArray *activeTracks;
    NSMutableArray *samplesBuffer;
}

@end