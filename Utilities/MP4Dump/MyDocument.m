//
//  MyDocument.m
//  MP4Dump
//
//  Created by Damiano Galassi on 27/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
#include "mp4v2.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers,
    // you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    [textView insertText:result];
    [textView setContinuousSpellCheckingEnabled:NO];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
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
    NSString * tempFile = [AppSupportDirectory stringByAppendingPathComponent:@"temp.txt"];
    
    MP4FileHandle fileHandle = MP4Read([[absoluteURL path] UTF8String]);
    FILE * file = fopen([tempFile UTF8String], "w");
    //MP4LogSetLevel(MP4_LOG_INFO);
    MP4Dump(fileHandle, file);

    if ( outError != NULL && !fileHandle) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
        
        return NO;
	}

    fclose(file);
    MP4Close(fileHandle);
    result = [NSString stringWithContentsOfFile:tempFile encoding:NSASCIIStringEncoding error:outError];

    return YES;
}

@end
