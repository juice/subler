//
//  MP42MkvFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"

@class SBSubSerializer;

@interface MP42SrtImporter : MP42FileImporter {
    SBSubSerializer * ss;
    
    NSMutableArray *activeTracks;
}

@end