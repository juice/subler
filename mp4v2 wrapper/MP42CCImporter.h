//
//  MP42CCFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 05/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"

@interface MP42CCImporter : MP42FileImporter {
    NSThread *dataReader;
    NSInteger readerStatus;
    
    NSMutableArray *samplesBuffer;
    NSMutableArray *activeTracks;
}

@end