//
//  SubUtilities.m
//  Subler
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 Perian. All rights reserved.
//

#import "SubUtilities.h"

@implementation SBSample

-(void) dealloc
{
    [title release];
    [super dealloc];
}

@synthesize timestamp;
@synthesize title;

@end

@implementation SubSerializer
-(id)init
{
	if (self = [super init]) {
		lines = [[NSMutableArray alloc] init];
		finished = NO;
		last_begin_time = last_end_time = 0;
		linesInput = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[lines release];
	[super dealloc];
}

static CFComparisonResult CompareLinesByBeginTime(const void *a, const void *b, void *unused)
{
	SubLine *al = (SubLine*)a, *bl = (SubLine*)b;
	
	if (al->begin_time > bl->begin_time) return kCFCompareGreaterThan;
	if (al->begin_time < bl->begin_time) return kCFCompareLessThan;
	
	if (al->no > bl->no) return kCFCompareGreaterThan;
	if (al->no < bl->no) return kCFCompareLessThan;
	return kCFCompareEqualTo;
}

/*static int cmp_uint(const void *a, const void *b)
{
	unsigned av = *(unsigned*)a, bv = *(unsigned*)b;
	
	if (av > bv) return 1;
	if (av < bv) return -1;
	return 0;
}*/

-(void)addLine:(SubLine *)line
{
	if (line->begin_time >= line->end_time) {
		if (line->begin_time)
			//Codecprintf(NULL, "Invalid times (%d and %d) for line \"%s\"", line->begin_time, line->end_time, [line->line UTF8String]);
		return;
	}
	
	line->no = linesInput++;
	
	int nlines = [lines count];
	
	if (!nlines || line->begin_time > ((SubLine*)[lines objectAtIndex:nlines-1])->begin_time) {
		[lines addObject:line];
	} else {
		CFIndex i = CFArrayBSearchValues((CFArrayRef)lines, CFRangeMake(0, nlines), line, CompareLinesByBeginTime, NULL);
		
		if (i >= nlines)
			[lines addObject:line];
		else
			[lines insertObject:line atIndex:i];
	}
	
}

-(SubLine*)getNextRealSerializedPacket
{
	int nlines = [lines count];
	SubLine *first = [lines objectAtIndex:0];
    NSMutableString *str;
	int i;
    
	if (!finished) {
		if (nlines > 1) {
			unsigned maxEndTime = first->end_time;
			
			for (i = 1; i < nlines; i++) {
				SubLine *l = [lines objectAtIndex:i];
				
				if (l->begin_time >= maxEndTime) {
					goto canOutput;
				}
				
				maxEndTime = MAX(maxEndTime, l->end_time);
			}
		}
		
		return nil;
	}

canOutput:
	str = [NSMutableString stringWithString:first->line];
	unsigned begin_time = last_end_time, end_time = first->end_time;
	int deleted = 0;
    
	for (i = 1; i < nlines; i++) {
		SubLine *l = [lines objectAtIndex:i];
		if (l->begin_time >= end_time) break;
		
		//shorten packet end time if another shorter time (begin or end) is found
		//as long as it isn't the begin time
		end_time = MIN(end_time, l->end_time);
		if (l->begin_time > begin_time)
			end_time = MIN(end_time, l->begin_time);
		
		if (l->begin_time <= begin_time)
			[str appendString:l->line];
	}
	
	for (i = 0; i < nlines; i++) {
		SubLine *l = [lines objectAtIndex:i - deleted];
		
		if (l->end_time == end_time) {
			[lines removeObjectAtIndex:i - deleted];
			deleted++;
		}
	}
	
	return [[SubLine alloc] initWithLine:str start:begin_time end:end_time];
}

-(SubLine*)getSerializedPacket
{
	int nlines = [lines count];
    
	if (!nlines) return nil;
	
	SubLine *nextline = [lines objectAtIndex:0], *ret;
	
	if (nextline->begin_time > last_end_time) {
		ret = [[SubLine alloc] initWithLine:@"\n" start:last_end_time end:nextline->begin_time];
	} else {
		ret = [self getNextRealSerializedPacket];
	}
	
	if (!ret) return nil;
	
	last_begin_time = ret->begin_time;
	last_end_time   = ret->end_time;
    
	return [ret autorelease];
}

-(void)setFinished:(BOOL)_finished
{
	finished = _finished;
}

-(BOOL)isEmpty
{
	return [lines count] == 0;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"lines left: %d finished inputting: %d",[lines count],finished];
}
@end

@implementation SubLine
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e
{
	if (self = [super init]) {
		if ([l characterAtIndex:[l length]-1] != '\n') l = [l stringByAppendingString:@"\n"];
		line = [l retain];
		begin_time = s;
		end_time = e;
		no = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[line release];
	[super dealloc];
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"\"%@\", from %d s to %d s",[line substringToIndex:[line length]-1],begin_time,end_time];
}
@end

static unsigned ParseSubTime(const char *time, unsigned secondScale, BOOL hasSign)
{
	unsigned hour, minute, second, subsecond, timeval;
	char separator;
	int sign = 1;
	
	if (hasSign && *time == '-') {
		sign = -1;
		time++;
	}
	
	if (sscanf(time,"%u:%u:%u%[,.:]%u",&hour,&minute,&second,&separator,&subsecond) < 5)
		return 0;
	
	timeval = hour * 60 * 60 + minute * 60 + second;
	timeval = secondScale * timeval + subsecond;
	
	return timeval * sign;
}

NSMutableString *STStandardizeStringNewlines(NSString *str)
{
    if(str == nil)
		return nil;
	NSMutableString *ms = [NSMutableString stringWithString:str];
	[ms replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	[ms replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	return ms;
}

static const short frequencies[] = {
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
0, 1026, 29, -1258, 539, -930, -652, -815, -487, -2526, -2161, 146, -956, -914, 1149, -102, 
293, -2675, -923, -597, 339, 110, 247, 9, 0, 1024, 1239, 0, 0, 0, 0, 0, 
0, 1980, 1472, 1733, -304, -4086, 273, 582, 333, 2479, 1193, 5014, -1039, 1964, -2025, 1083, 
-154, -5000, -1725, -4843, -366, -1850, -191, 1356, -2262, 1648, 1475, 0, 0, 0, 0, 0, 
0, 0, 0, 0, 0, -458, 0, 0, 0, 0, 300, 0, 0, 300, 601, 0, 
0, 0, -2247, 0, 0, 0, 0, 0, 0, 0, 3667, 0, 0, 3491, 3567, 0, 
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1993, 0, 0, 0, 0, 0, 
0, 0, 0, 0, 0, 0, 1472, 0, 0, 0, 5000, 0, 601, 0, 1993, 0, 
0, 1083, 0, 672, -458, 0, 0, -458, 1409, 0, 0, 0, 0, 0, 1645, 425, 
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 601, -1123, 
-1912, 4259, 2573, 8866, 55, 0, 0, -2247, -831, -3788, -3043, 0, 0, 3412, 2921, 1251, 
0, 0, 1377, 520, 1344, 0, -1123, 0, 0, -1213, 2208, -458, -794, 2636, 3824, 0};

static BOOL DifferentiateLatin12(const unsigned char *data, int length)
{
	// generated from french/german (latin1) and hungarian/romanian (latin2)
	
	int frcount = 0;
	
	while (length--) {
		frcount += frequencies[*data++];
	}
	
	return frcount <= 0;
}

extern NSString *STLoadFileWithUnknownEncoding(NSString *path)
{
	NSData *data = [NSData dataWithContentsOfMappedFile:path];
    if (!data)
        return nil;

	UniversalDetector *ud = [[UniversalDetector alloc] init];
	NSString *res = nil;
	NSStringEncoding enc;
	NSString *enc_str;
	BOOL latin2;

	[ud analyzeData:data];
	
	enc = [ud encoding];
	enc_str = [ud MIMECharset];
	latin2 = [enc_str isEqualToString:@"windows-1250"];
	
	if (latin2) {
		if (DifferentiateLatin12([data bytes], [data length])) { // seems to actually be latin1
			enc = NSWindowsCP1252StringEncoding;
		}
	}
	
	res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
	
	if (!res) {
		if (latin2) {
			enc = (enc == NSWindowsCP1252StringEncoding) ? NSWindowsCP1250StringEncoding : NSWindowsCP1252StringEncoding;
			res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
		}
	}
	[ud release];
	
	return res;
}

int LoadSRTFromPath(NSString *path, SubSerializer *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return 0;
    
	if ([srt characterAtIndex:0] == 0xFEFF) [srt deleteCharactersInRange:NSMakeRange(0,1)];
	if ([srt characterAtIndex:[srt length]-1] != '\n') [srt appendFormat:@"%c",'\n'];
	
	NSScanner *sc = [NSScanner scannerWithString:srt];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];
	
	unsigned startTime=0, endTime=0;
	
	enum {
		INITIAL,
		TIMESTAMP,
		LINES
	} state = INITIAL;
	
	do {
		switch (state) {
			case INITIAL:
				if ([sc scanInt:NULL] == TRUE && [sc scanUpToString:@"\n" intoString:&res] == FALSE) {
					state = TIMESTAMP;
					[sc scanString:@"\n" intoString:nil];
				} else
					[sc setScanLocation:[sc scanLocation]+1];
				break;
			case TIMESTAMP:
				[sc scanUpToString:@" --> " intoString:&res];
				[sc scanString:@" --> " intoString:nil];
				startTime = ParseSubTime([res UTF8String], 1000, NO);
				
				[sc scanUpToString:@"\n" intoString:&res];
				[sc scanString:@"\n" intoString:nil];
				endTime = ParseSubTime([res UTF8String], 1000, NO);
				state = LINES;
				break;
			case LINES:
				[sc scanUpToString:@"\n\n" intoString:&res];
				[sc scanString:@"\n\n" intoString:nil];
				SubLine *sl = [[SubLine alloc] initWithLine:res start:startTime end:endTime];
				[ss addLine:[sl autorelease]];
				state = INITIAL;
				break;
		};
	} while (![sc isAtEnd]);
    
    return 1;
}

int LoadChaptersFromPath(NSString *path, NSMutableArray *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return 0;

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

    if ([srt characterAtIndex:0] == 'C') { // ogg tools format
        do {
            switch (state) {
                case TIMESTAMP:
                    [sc scanUpToString:@"=" intoString:nil];
                    [sc scanString:@"=" intoString:nil];
                    [sc scanUpToString:@"\n" intoString:&res];
                    [sc scanString:@"\n" intoString:nil];
                    time = ParseSubTime([res UTF8String], 1000, NO);

                    state = LINES;
                    break;
                case LINES:
                    [sc scanUpToString:@"=" intoString:nil];
                    [sc scanString:@"=" intoString:nil];
                    [sc scanUpToString:@"\n" intoString:&res];
                    [sc scanString:@"\n" intoString:nil];

                    SBSample *chapter = [[SBSample alloc] init];
                    chapter.timestamp = time;
                    chapter.title = res;
                    [ss addObject:chapter];
                    [chapter release];
                    state = TIMESTAMP;
                    break;
            };
        } while (![sc isAtEnd]);
    }
    else  //mp4chaps format
    {
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
                    
                    SBSample *chapter = [[SBSample alloc] init];
                    chapter.timestamp = time;
                    chapter.title = res;
                    [ss addObject:chapter];
                    [chapter release];
                    state = TIMESTAMP;
                    break;
            };
        } while (![sc isAtEnd]);
    }
    
    return 1;
}
