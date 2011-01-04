//
//  SBPresetManager.h
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MP42Metadata;

@interface SBPresetManager : NSObject {
@private
    NSMutableArray *presets;
}

+ (SBPresetManager*)sharedManager;

- (void) newSetFromExistingMetadata:(MP42Metadata*)set;
- (BOOL) savePresets;

@end
