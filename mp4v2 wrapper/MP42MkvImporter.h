//
//  MP42MkvFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"

@interface MP42MkvImporter : MP42FileImporter {

    struct MatroskaFile	*matroskaFile;
	struct StdIoStream  *ioStream;

}

@end