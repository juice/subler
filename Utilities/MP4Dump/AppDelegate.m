//
//  AppDelegate.m
//  MP4Dump
//
//  Created by Damiano Galassi on 17/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#include "mp4v2.h"

NSString *libraryPath = nil;

void logCallback(MP4LogLevel loglevel, const char* fmt, va_list ap)
{
    const char* level;
    switch (loglevel) {
        case 0:
            level = "None";
            break;
        case 1:
            level = "Error";
            break;
        case 2:
            level = "Warning";
            break;
        case 3:
            level = "Info";
            break;
        case 4:
            level = "Verbose1";
            break;
        case 5:
            level = "Verbose2";
            break;
        case 6:
            level = "Verbose3";
            break;
        case 7:
            level = "Verbose4";
            break;
        default:
            level = "Unknown";
            break;
    }

    if (!libraryPath) {
        NSString * libraryDir = [NSSearchPathForDirectoriesInDomains( NSLibraryDirectory,
                                                                     NSUserDomainMask,
                                                                     YES ) objectAtIndex:0];
        NSString * AppSupportDirectory = [[libraryDir stringByAppendingPathComponent:@"Application Support"]
                                          stringByAppendingPathComponent:@"MP4Dump"];
        if( ![[NSFileManager defaultManager] fileExistsAtPath:AppSupportDirectory] )
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:AppSupportDirectory
                                                       attributes:nil];
        }
        libraryPath = [[AppSupportDirectory stringByAppendingPathComponent:@"temp.txt"] retain];
        
    }

    FILE * file = fopen([libraryPath UTF8String], "a");

    fprintf(file, "%s: ", level);
    vfprintf(file, fmt, ap);
    fprintf(file, "\n");

    fclose(file);

}

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    MP4LogSetLevel(MP4_LOG_INFO);
    MP4SetLogCallback(logCallback);
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

@end
