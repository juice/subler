//
//  MP42FileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MP42FileImporter : NSObject {
    NSURL   * file;
    
    NSInteger        chapterTrackId;
    NSMutableArray * tracksArray;

    id delegate;
}

@property(readonly) NSMutableArray  *tracksArray;

- (id)initWithDelegate:(id)del andFile:(NSURL *)fileUrl;

@end

@interface NSObject (MP42FileImporterDelegateMethod)
- (void) fileLoaded;

@end