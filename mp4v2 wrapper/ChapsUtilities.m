//
//  ChapsUtilities.m
//  Subler
//
//  Created by Damiano Galassi on 17/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ChapsUtilities.h"
#import "SubUtilities.h"

@implementation SBChapter

-(void) dealloc
{
    [super dealloc];
    [title release];
}

@synthesize duration;
@synthesize title;

@end

void LoadChaptersFromPath(NSString *path, NSMutableArray *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return;

	if ([srt characterAtIndex:0] == 0xFEFF) [srt deleteCharactersInRange:NSMakeRange(0,1)];
	if ([srt characterAtIndex:[srt length]-1] != '\n') [srt appendFormat:@"%c",'\n'];

	NSScanner *sc = [NSScanner scannerWithString:srt];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];

	unsigned time=0;

	enum {
		TIMESTAMP,
		LINES
	} state = TIMESTAMP;

	do {
		switch (state) {
			case TIMESTAMP:
				[sc scanUpToString:@" " intoString:&res];
				[sc scanString:@" " intoString:nil];
				time = ParseSubTime([res UTF8String], 1000, NO);

				state = LINES;
				break;
			case LINES:
				[sc scanUpToString:@"\n" intoString:&res];
				[sc scanString:@"\n" intoString:nil];
                
                SBChapter *chapter = [[SBChapter alloc] init];
                chapter.duration = time;
                chapter.title = res;
                [ss addObject:chapter];
                [chapter release];
				state = TIMESTAMP;
				break;
		};
	} while (![sc isAtEnd]);
}
