//
//  SubUtilities.m
//  Subler
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SubUtilities.h"

@implementation SBChapter

-(void) dealloc
{
    [title release];
    [super dealloc];
}

@synthesize timestamp;
@synthesize title;

@end


@implementation SubLine
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e
{
	if (self = [super init]) {
		if ([l characterAtIndex:[l length]-1] != '\n') l = [l stringByAppendingString:@"\n"];
		line = [l retain];
		begin_time = s;
		end_time = e;
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
	return [NSString stringWithFormat:@"\"%@\", from %d s to %d s",line,begin_time,end_time];
}
@end

@implementation SubSerializer
-(id)init
{
	if (self = [super init]) {
		lines = [[NSMutableArray alloc] init];
		outpackets = [[NSMutableArray alloc] init];
		finished = NO;
		write_gap = NO;
		toReturn = nil;
		last_time = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[outpackets release];
	[lines release];
	[super dealloc];
}

-(void)addLine:(SubLine *)sline
{
	if (sline->begin_time < sline->end_time)
		[lines addObject:sline];
}

static NSInteger cmp_line(id a, id b, void* unused)
{			
	SubLine *av = (SubLine*)a, *bv = (SubLine*)b;
	
	if (av->begin_time > bv->begin_time) return NSOrderedDescending;
	if (av->begin_time < bv->begin_time) return NSOrderedAscending;
	return NSOrderedSame;
}

static int cmp_uint(const void *a, const void *b)
{
	unsigned av = *(unsigned*)a, bv = *(unsigned*)b;
	
	if (av > bv) return 1;
	if (av < bv) return -1;
	return 0;
}

static bool isinrange(unsigned base, unsigned test_s, unsigned test_e)
{
	return (base >= test_s) && (base < test_e);
}

-(void)refill
{
	unsigned num = [lines count];
	unsigned min_allowed = finished ? 1 : 2;
	if (num < min_allowed) return;
	unsigned times[num*2], last_last_end = 0;
	SubLine *slines[num], *last=nil;
	bool last_has_invalid_end = false;
	
	[lines sortUsingFunction:cmp_line context:nil];
	[lines getObjects:slines];
#ifdef SS_DEBUG
	NSLog(@"pre - %@",lines);
#endif	
	//leave early if all subtitle lines overlap
	if (!finished) {
		bool all_overlap = true;
		int i;
		
		for (i=0;i < num-1;i++) {
			SubLine *c = slines[i], *n = slines[i+1];
			if (c->end_time <= n->begin_time) {all_overlap = false; break;}
		}
		
		if (all_overlap) return;
		
		for (i=0;i < num-1;i++) {
			if (isinrange(slines[num-1]->begin_time, slines[i]->begin_time, slines[i]->end_time)) {
				num = i + 1; break;
			}
		}
	}
	
	for (int i=0;i < num;i++) {
		times[i*2]   = slines[i]->begin_time;
		times[i*2+1] = slines[i]->end_time;
	}
	
	qsort(times, num*2, sizeof(unsigned), cmp_uint);
	
	for (int i=0;i < num*2; i++) {
		if (i > 0 && times[i-1] == times[i]) continue;
		NSMutableString *accum = nil;
		unsigned start = times[i], last_end = start, next_start=times[num*2-1], end;
		bool finishedOutput = false, is_last_line = false;
		
		// Add on packets until we find one that marks it ending (by starting later)
		// ...except if we know this is the last input packet from the stream, then we have to explicitly flush it
		if (finished && (times[i] == slines[num-1]->begin_time || times[i] == slines[num-1]->end_time)) finishedOutput = is_last_line = true;
		
		for (int j=0; j < num; j++) {
			if (isinrange(times[i], slines[j]->begin_time, slines[j]->end_time)) {
				
				// find the next line that starts after this one
				if (j != num-1) {
					unsigned ns = slines[j]->end_time;
					for (int h = j; h < num; h++) if (slines[h]->begin_time != slines[j]->begin_time) {ns = slines[h]->begin_time; break;}
                    next_start = MIN(next_start, ns);
				} else next_start = slines[j]->end_time;
				
				last_end = MAX(slines[j]->end_time, last_end);
				if (accum) [accum appendString:slines[j]->line]; else accum = [[slines[j]->line mutableCopy] autorelease];
			} else if (j == num-1) finishedOutput = true;
		}
		
		if (accum && finishedOutput) {
			[accum deleteCharactersInRange:NSMakeRange([accum length] - 1, 1)]; // delete last newline
#ifdef SS_DEBUG
			NSLog(@"%d - %d %d",start,last_end,next_start);	
#endif
			if (last_has_invalid_end) {
				if (last_end < next_start) { 
					int j, set;
					for (j=i; j >= 0; j--) if (times[j] == last->begin_time) break;
					set = times[j+1];
					last->end_time = set;
				} else last->end_time = MIN(last_last_end,start); 
			}
			end = last_end;
			last_has_invalid_end = false;
			if (last_end > next_start && !is_last_line) last_has_invalid_end = true;
			SubLine *event = [[SubLine alloc] initWithLine:accum start:start end:end];
			
			[outpackets addObject:event];
			
			last_last_end = last_end;
			last = event;
		}
	}
	
	if (last_has_invalid_end) {
		last->end_time = times[num*2 - 3]; // end time of line before last
	}
#ifdef SS_DEBUG
	NSLog(@"out - %@",outpackets);
#endif
	
	if (finished) [lines removeAllObjects];
	else {
		num = [lines count];
		for (int i = 0; i < num-1; i++) {
			if (isinrange(slines[num-1]->begin_time, slines[i]->begin_time, slines[i]->end_time)) break;
			[lines removeObject:slines[i]];
		}
	}
#ifdef SS_DEBUG
	NSLog(@"post - %@",lines);
#endif
}

-(SubLine*)_getSerializedPacket
{
	if ([outpackets count] == 0)  {
		[self refill];
		if ([outpackets count] == 0) 
			return nil;
	}
	
	SubLine *sl = [outpackets objectAtIndex:0];
	[outpackets removeObjectAtIndex:0];
	
	[sl autorelease];
	return sl;
}

-(SubLine*)getSerializedPacket
{
	if (!last_time) {
		SubLine *ret = [self _getSerializedPacket];
		if (ret) {
			last_time = ret->end_time;
			write_gap = YES;
		}
		return ret;
	}
	
restart:
	
	if (write_gap) {
		SubLine *next = [self _getSerializedPacket];
		SubLine *sl;
        
		if (!next) return nil;
        
		toReturn = [next retain];
		
		write_gap = NO;
		
		if (toReturn->begin_time > last_time) sl = [[SubLine alloc] initWithLine:@"\n" start:last_time end:toReturn->begin_time];
		else goto restart;
		
		return [sl autorelease];
	} else {
		SubLine *ret = toReturn;
		last_time = ret->end_time;
		write_gap = YES;
		
		toReturn = nil;
		return [ret autorelease];
	}
}

-(void)setFinished:(BOOL)f
{
	finished = f;
}

-(BOOL)isEmpty
{
	return [lines count] == 0 && [outpackets count] == 0 && !toReturn;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"i: %d o: %d finished inputting: %d",[lines count],[outpackets count],finished];
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
674, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
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

void LoadSRTFromPath(NSString *path, SubSerializer *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return;
    
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
}

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

                    SBChapter *chapter = [[SBChapter alloc] init];
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
                    
                    SBChapter *chapter = [[SBChapter alloc] init];
                    chapter.timestamp = time;
                    chapter.title = res;
                    [ss addObject:chapter];
                    [chapter release];
                    state = TIMESTAMP;
                    break;
            };
        } while (![sc isAtEnd]);
    }
}
