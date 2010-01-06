//
//  tagChimpController.m
//  Subler
//
//  Created by Damiano Galassi on 06/01/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "tagChimpController.h"
#import "SBTableView.h"
#import "MP42File.h"

@implementation tagChimpController

- (id)initWithDelegate:(id)del
{
	if (self = [super initWithWindowNibName:@"MetadataImport"]) {        
		delegate = del;
    }

	return self;
}

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;
    
    NSInteger right = [(NSArray*) context indexOfObject:rdict];
    NSInteger left = [(NSArray*) context indexOfObject:ldict];
    
    if (right < left)
        rc = NSOrderedDescending;
    else
        rc = NSOrderedAscending;
    
    return rc;
}

- (IBAction) search: (id) sender {
    // url
    NSString *searchTerms = [searchField stringValue];
    if (![searchTerms length])
        return;

    if (theConnection) {
        [theConnection cancel];
        [theConnection release];
    }
    if (receivedXml) {
        [receivedXml release];
        receivedXml = nil;
        [movieTitleTable reloadData];
        [metadataTable reloadData];
    }

    searchTerms = [searchTerms stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSString *pageUrl = [NSString stringWithFormat:@"https://www.tagchimp.com/ape/search.php?token=10976026764A4CBEE9463B5&type=search&title=%@&totalChapters=0&limit=25&locked=false", searchTerms];

    // create the request
    NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:pageUrl]
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                          timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data

    theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (theConnection) {
        // Create the NSMutableData that will hold
        // the received data
        // receivedData is declared as a method instance elsewhere
        receivedData=[[NSMutableData data] retain];
        [progress startAnimation:self];
        [progress setHidden:NO];
    } else {
        [progress stopAnimation:self];
        [progress setHidden:YES];
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
    
    // it can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    // receivedData is declared as a method instance elsewhere
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the receivedData
    // receivedData is declared as a method instance elsewhere
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // release the connection, and the data object
    if ([receivedData length]) {
        receivedXml = [[NSXMLDocument alloc]initWithData:receivedData options:NSXMLDocumentTidyXML error:nil];
        [self tagChimpXmlToMP42Metadata: receivedXml];
        [movieTitleTable reloadData];
    }
    [progress setHidden:YES];
    [progress stopAnimation:self];
    [connection release];
    theConnection = nil;
}


- (void) tagChimpXmlToMP42Metadata: (NSXMLDocument *) xmlDocument {
    NSError *err=nil;
    NSArray *nodes = [receivedXml nodesForXPath:@"./items/movie" error:&err];
    if (metadataArray)
        [metadataArray release];
        
    metadataArray = [[NSMutableArray alloc] initWithCapacity:[nodes count]];
    
    for (NSXMLElement *element in nodes) {
        MP42Metadata * metadata = [[MP42Metadata alloc] init];
        NSArray *tag = [element nodesForXPath:@"./movieTags/info/movieTitle"
                                              error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Name"];
        
        tag = [element nodesForXPath:@"./movieTags/info/releaseDate"
                                     error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Release Date"];
        
        tag = [element nodesForXPath:@"./movieTags/info/genre"
                                     error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Genre"];
        
        tag = [element nodesForXPath:@"./movieTags/info/shortDescription"
                                     error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Description"];
        
        [metadataArray addObject:metadata];
    }
    
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (receivedXml) {
        if (aTableView == movieTitleTable) {
            NSError *err=nil;
            NSArray *nodes = [receivedXml nodesForXPath:@"./items/totalResults"
                                                  error:&err];
            if ([nodes count])
                return [[[nodes objectAtIndex:0] stringValue] integerValue];
        }
        else {
            return [tagsArray count];
        }
    }

    return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
    if (receivedXml) {
        if (aTableView == movieTitleTable) {
            NSError *err=nil;
            NSString *XPath = [NSString stringWithFormat:@"./items/movie[%d]/movieTags/info/movieTitle",
                               rowIndex +1];
            NSArray *nodes = [receivedXml nodesForXPath:XPath error:&err];
            return [[nodes objectAtIndex:0] stringValue];
        }
        else {
            if ([aTableColumn.identifier isEqualToString:@"name"])
                return [tagsArray objectAtIndex:rowIndex];
    
            if ([aTableColumn.identifier isEqualToString:@"value"]) 
                return [tags objectForKey:[tagsArray objectAtIndex:rowIndex]];            
        }
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([movieTitleTable selectedRow] != -1) {
        MP42Metadata *metadata = [metadataArray objectAtIndex:[movieTitleTable selectedRow]];
        tags = metadata.tagsDict;
        tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:[metadata availableMetadata]] retain];
        [metadataTable reloadData];
    }
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate metadataImportDone:nil];
}

@end
