//
//  MP42MkvFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"
#import <QTKit/QTKit.h>

@interface MP42MovImporter : MP42FileImporter {
    QTMovie         *sourceFile;
    
    NSThread *dataReader;
    NSInteger readerStatus;
    
    NSMutableArray *activeTracks;
    NSMutableArray *samplesBuffer;
    
    CGFloat progress;
}

@end