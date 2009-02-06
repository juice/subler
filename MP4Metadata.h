//
//  MP4Metadata.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MP4Metadata : NSObject {
    NSString        *sourcePath;
    NSMutableDictionary    *tagsDict;
}

-(id) initWithSourcePath:(NSString *)source;
-(void) readMetaData;

@property(readonly) NSMutableDictionary    *tagsDict;

@end
