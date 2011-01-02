/*
 *  MatroskaFile.c
 *  Subler
 *
 *  Created by Ryan Walklin on 23/09/09.
 *  Copyright 2009 Test Toast. All rights reserved.
 *
 */

#include <stdlib.h> 
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>

#include "MatroskaParser.h"
#include "MatroskaFile.h"

#pragma mark Parser callbacks

#define CACHESIZE 65536

/* StdIoStream methods */ 

/* read count bytes into buffer starting at file position pos 
 * return the number of bytes read, -1 on error or 0 on EOF 
 */ 
int   StdIoRead(StdIoStream *st, uint64_t pos, void *buffer, int count) { 
	size_t  rd; 
	if (fseeko(st->fp, pos, SEEK_SET) == -1) { 
		st->error = errno; 
		return -1; 
	} 
	rd = fread(buffer, 1, count, st->fp); 
	if (rd == 0) { 
		if (feof(st->fp)) 
			return 0; 
		st->error = errno; 
		return -1; 
	} 
	return rd; 
} 

/* scan for a signature sig(big-endian) starting at file position pos 
 * return position of the first byte of signature or -1 if error/not found 
 */ 
longlong StdIoScan(StdIoStream *st, uint64_t start, uint32_t signature) { 
	uint32_t         c; 
	uint32_t    cmp = 0; 
	FILE              *fp = st->fp; 
	
	if (fseeko(fp, start, SEEK_SET)) 
		return -1; 
	
	while ((c = getc(fp)) != EOF) { 
		cmp = ((cmp << 8) | c) & 0xffffffff; 
		if (cmp == signature) 
			return ftell(fp) - 4; 
	} 
	
	return -1; 
} 

/* return cache size, this is used to limit readahead */ 
unsigned StdIoGetCacheSize(StdIoStream *st) { 
	return CACHESIZE; 
} 

/* return last error message */ 
const char *StdIoGetLastError(StdIoStream *st) { 
	return strerror(st->error); 
} 

/* memory allocation, this is done via stdlib */ 
void  *StdIoMalloc(StdIoStream *st, size_t size) { 
	return malloc(size); 
} 

void  *StdIoRealloc(StdIoStream *st, void *mem, size_t size) { 
	return realloc(mem,size); 
} 

void  StdIoFree(StdIoStream *st, void *mem) { 
	free(mem); 
} 

/* progress report handler for lengthy operations 
 * returns 0 to abort operation, nonzero to continue 
 */ 
int StdIoProgress(StdIoStream *st, uint64_t cur, uint64_t max) { 
	return 1; 
} 

MatroskaFile *openMatroskaFile(char *filePath, StdIoStream *ioStream)
{
	char err_msg[256]; 
	
	/* fill in I/O object */ 
	ioStream->base.read = StdIoRead; 
	ioStream->base.scan = StdIoScan; 
	ioStream->base.getcachesize = StdIoGetCacheSize; 
	ioStream->base.geterror = StdIoGetLastError; 
	ioStream->base.memalloc = StdIoMalloc; 
	ioStream->base.memrealloc = StdIoRealloc; 
	ioStream->base.memfree = StdIoFree; 
	ioStream->base.progress = StdIoProgress; 
	
	/* open source file */ 
	ioStream->fp = fopen(filePath,"r"); 
	if (ioStream->fp == NULL) { 
		fprintf(stderr, "Can't open '%s': %s\n", filePath, strerror(errno)); 
		return NULL; 
	} 
	
	setvbuf(ioStream->fp, NULL, _IOFBF, CACHESIZE); 
	
	/* initialize matroska parser */ 
	MatroskaFile *mf = mkv_Open(&ioStream->base, /* pointer to I/O object */ 
					   //		  0, /* starting position in the file */ 
					   //		  0,
					   		  err_msg, sizeof(err_msg)); /* error message is returned here */ 
	
	if (mf == NULL) 
	{ 
		fclose(ioStream->fp); 
		fprintf(stderr, "Can't parse Matroska file: %s\n", err_msg); 
		return NULL; 
	} 
	
	return mf;	
}
