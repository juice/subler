//
//  SBPresetManager.m
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBPresetManager.h"
#import "MP42File.h"

static SBPresetManager *sharedPresetManager = nil;

@implementation SBPresetManager

+ (SBPresetManager*)sharedManager
{
    if (sharedPresetManager == nil) {
        sharedPresetManager = [[super allocWithZone:NULL] init];
    }
    return sharedPresetManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedManager] retain];
}

- (id)init {
    if ((self = [super init])) {
        presets = [[NSMutableArray alloc] init];

        NSString *appSupportDir;
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if ([allPaths count])
            appSupportDir = [allPaths objectAtIndex:0];
        
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

- (void) newSetFromExistingMetadata:(MP42Metadata*)set;
{
    [presets addObject:[set copy]];
}

- (BOOL) loadPresets
{
    NSString *file;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    MP42Metadata *newPreset;

    NSString *appSupportPath;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count])
        appSupportPath = [allPaths objectAtIndex:0];

    if (!appSupportPath)
        return NO;

    NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:appSupportPath];
    while ((file = [dirEnum nextObject]))
    {
        if ([[file pathExtension] isEqualToString: @"sbpreset"])
        {
            newPreset = [NSKeyedUnarchiver unarchiveObjectWithFile:[appSupportPath stringByAppendingPathComponent:file]];
            [presets addObject:newPreset];
        }
    }

    if ( ![presets count] )
        return NO;
    else
        return YES;
}

- (BOOL) savePresets
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL noErr = YES;

    NSString *appSupportPath;
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count])
        appSupportPath = [allPaths objectAtIndex:0];

    if (!appSupportPath)
        return NO;

    if( ![fileManager fileExistsAtPath:appSupportPath] )
        [fileManager createDirectoryAtPath:appSupportPath attributes:nil];

    MP42Metadata *object;

    for( object in presets )
    {
        NSString * saveLocation = [NSString stringWithFormat:@"%@/%@.sbpreset", appSupportPath, [object name]];
        if (![fileManager fileExistsAtPath:saveLocation]) 
        {
            noErr = [NSKeyedArchiver archiveRootObject:object
                                                toFile:saveLocation];
        }
    }
    return noErr;
}


@end
