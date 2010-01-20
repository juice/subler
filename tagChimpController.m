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

        NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [ps setHeadIndent: -10.0];
        [ps setAlignment:NSRightTextAlignment];
        detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                           [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                           ps, NSParagraphStyleAttributeName,
                           [NSColor grayColor], NSForegroundColorAttributeName,
                           nil] retain];
    }

	return self;
}

- (void)awakeFromNib {
    tabCol = [[[metadataTable tableColumns] objectAtIndex:1] retain];
    [[searchField cell] setSearchMenuTemplate:searchFieldMenu];
    [[searchField cell] setPlaceholderString:[[searchFieldMenu itemWithTag:0] title]];
}

- (NSAttributedString *) boldString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
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

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];
    NSInteger tag = [anItem tag];

    if (tag == NSSearchFieldRecentsTitleMenuItemTag)
        return NO;
    
    if (tag == NSSearchFieldNoRecentsMenuItemTag)
        return NO;
    
    if (tag == 20)
        return NO;

    if (tag == videoKind)
        [(NSMenuItem*)anItem setState:NSOnState];
    else
        [(NSMenuItem*)anItem setState:NSOffState];
    
    if (action == @selector(addMetadata:))
        return NO;

    return YES;
}


- (IBAction) searchType: (NSMenuItem *) sender {
    videoKind = [sender tag];
    [[searchField cell] setPlaceholderString:[sender title]];
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
        [addButton setEnabled:NO];
    }

    NSString *searchType;
    NSString *totalChapters = @"X";
    NSInteger limit = 150;
    searchTerms = [searchTerms stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    
    switch(videoKind) {
        case 0:
            searchType = [NSString stringWithFormat:@"&type=search&title=%@&limit=%d&totalChapters=%@&videoKind=Movie",
                          searchTerms, limit, totalChapters];
            break;
        case 1:
            searchType = [NSString stringWithFormat:@"&type=search&show=%@&totalChapters=%@&videoKind=TVShow&season=1", 
                          searchTerms, totalChapters];
            break;
        case 11:
            searchType = [NSString stringWithFormat:@"&type=search&title=%@&totalChapters=%@&videoKind=TVShow", 
                          searchTerms, totalChapters];
            break;
        case 2:
            searchType = [NSString stringWithFormat:@"&type=search&title=%@&limit=%d&totalChapters=%@&videoKind=MusicVideo", 
                          searchTerms, limit, totalChapters];
            break;
        case 3:
            searchType = [NSString stringWithFormat:@"&type=lookup&totalChapters=X&id=%@",
                          searchTerms];
            break;
        case 4:
            searchType = [NSString stringWithFormat:@"&type=lookup&totalChapters=X&amazon=%@",
                          searchTerms];
            break;
        case 5:
            searchType = [NSString stringWithFormat:@"&type=lookup&totalChapters=X&imdb=%@", 
                          searchTerms];
            break;
        case 6:
            searchType = [NSString stringWithFormat:@"&type=lookup&totalChapters=X&netflix=%@",
                          searchTerms];
            break;
        case 7:
            searchType = [NSString stringWithFormat:@"&type=lookup&totalChapters=X&gtin=%@",
                          searchTerms];
            break;
        default:
            searchType = [NSString stringWithFormat:@"&type=search&title=%@&limit=%d&totalChapters=%@&videoKind=Movie",
                          searchTerms, limit, totalChapters];
    }

    NSString *pageUrl = [NSString stringWithFormat:@"https://www.tagchimp.com/ape/search.php?token=10976026764A4CBEE9463B5%@", searchType];

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
        if ([metadataArray count]) {
            [addButton setEnabled:YES];
        }
        [movieTitleTable reloadData];
    }
    [progress setHidden:YES];
    [progress stopAnimation:self];
    [connection release];
    theConnection = nil;
}


- (NSArray *) tagChimpXmlToMP42Metadata: (NSXMLDocument *) xmlDocument {
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

        tag = [element nodesForXPath:@"./movieTags/info/kind"
                                        error:&err];
        if([tag count]) {
            NSString *tagValue = [[tag objectAtIndex:0] stringValue];
            if ([tagValue isEqualToString:@"Movie"])
                metadata.mediaKind = 9;
        }

        tag = [element nodesForXPath:@"./movieTags/info/releaseDateY"
                               error:&err];
        if([tag count] && [[[tag objectAtIndex:0] stringValue] integerValue]) {
            NSInteger year, month, day;
            year = [[[tag objectAtIndex:0] stringValue] integerValue];
            
            tag = [element nodesForXPath:@"./movieTags/info/releaseDateM"
                                   error:&err];
            if([tag count])
                month = [[[tag objectAtIndex:0] stringValue] integerValue];

            tag = [element nodesForXPath:@"./movieTags/info/releaseDateD"
                                       error:&err];
            if([tag count])
                day = [[[tag objectAtIndex:0] stringValue]integerValue];

            [metadata setTag:[NSString stringWithFormat:@"%d-%d-%d",year, month, day] forKey:@"Release Date"];
        }
        else {
            tag = [element nodesForXPath:@"./movieTags/info/releaseDate"
                                        error:&err];
            if([tag count])
                [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Release Date"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/genre"
                                     error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Genre"];

        tag = [element nodesForXPath:@"./movieTags/info/shortDescription"
                                     error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Description"];

        tag = [element nodesForXPath:@"./movieTags/info/longDescription"
                               error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Long Description"];

        tag = [element nodesForXPath:@"./movieTags/info/rating"
                                     error:&err];
        if([tag count]) {
            NSString* ratingCompareString = [[tag objectAtIndex:0] stringValue];
            [metadata setTag:[NSNumber numberWithInteger:[metadata ratingIndexFromString:ratingCompareString]] forKey:@"Rating"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/copyright"
                               error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Copyright"];

        tag = [element nodesForXPath:@"./movieTags/info/comments"
                               error:&err];
        if([tag count])
            [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Comments"];

        tag = [element nodesForXPath:@"./movieTags/info/cast/actor"
                               error:&err];
        if([tag count]) {
            NSString* tagValue = nil;
            for (NSXMLElement* actorName in tag) {
                if (tagValue)
                    tagValue = [NSString stringWithFormat:@"%@, %@", tagValue, [actorName stringValue]];
                else
                    tagValue = [actorName stringValue];
            }
            [metadata setTag:tagValue forKey:@"Cast"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/directors/director"
                               error:&err];
        if([tag count]) {
            NSString* tagValue = nil;
            for (NSXMLElement* actorName in tag) {
                if (tagValue)
                    tagValue = [NSString stringWithFormat:@"%@, %@", tagValue, [actorName stringValue]];
                else
                    tagValue = [actorName stringValue];
            }
            [metadata setTag:tagValue forKey:@"Director"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/producers/producer"
                               error:&err];
        if([tag count]) {
            NSString* tagValue = nil;
            for (NSXMLElement* actorName in tag) {
                if (tagValue)
                    tagValue = [NSString stringWithFormat:@"%@, %@", tagValue, [actorName stringValue]];
                else
                    tagValue = [actorName stringValue];
            }
            [metadata setTag:tagValue forKey:@"Producers"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/screenwriters/screenwriter"
                               error:&err];
        if([tag count]) {
            NSString* tagValue = nil;
            for (NSXMLElement* actorName in tag) {
                if (tagValue)
                    tagValue = [NSString stringWithFormat:@"%@, %@", tagValue, [actorName stringValue]];
                else
                    tagValue = [actorName stringValue];
            }
            [metadata setTag:tagValue forKey:@"Screenwriters"];
        }

        tag = [element nodesForXPath:@"./movieTags/info/artist/artistName"
                               error:&err];
        if([tag count]) {
            NSString* tagValue = nil;
            for (NSXMLElement* actorName in tag) {
                if (tagValue)
                    tagValue = [NSString stringWithFormat:@"%@, %@", tagValue, [actorName stringValue]];
                else
                    tagValue = [actorName stringValue];
            }
            [metadata setTag:tagValue forKey:@"Artist"];
        }
        
        //TV Show specific tags
        tag = [element nodesForXPath:@"./movieTags/info/kind"
                               error:&err];
        if([tag count])
            if ([[[tag objectAtIndex:0] stringValue] isEqualToString:@"TV Show"]) {
                tag = [element nodesForXPath:@"./movieTags/television/showName"
                                       error:&err];
                if([tag count])
                    [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TV Show"];

                tag = [element nodesForXPath:@"./movieTags/television/season"
                                       error:&err];
                if([tag count])
                    [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TV Season"];

                tag = [element nodesForXPath:@"./movieTags/television/episode"
                                       error:&err];
                if([tag count])
                    [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TV Episode #"];

                tag = [element nodesForXPath:@"./movieTags/television/episodeID"
                                       error:&err];
                if([tag count])
                    [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TV Episode ID"];

                tag = [element nodesForXPath:@"./movieTags/television/network"
                                       error:&err];
                if([tag count])
                    [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TV Network"];

                NSInteger track = 0, totalTracks = 0;
                tag = [element nodesForXPath:@"./movieTags/track/trackNum"
                                       error:&err];
                if([tag count])
                    track = [[[tag objectAtIndex:0] stringValue] integerValue];

                tag = [element nodesForXPath:@"./movieTags/track/trackTotal"
                                       error:&err];
                if([tag count])
                    totalTracks = [[[tag objectAtIndex:0] stringValue] integerValue];

                [metadata setTag:[NSString stringWithFormat:@"%d/%d", track, totalTracks] forKey:@"Track #"];
            }
        [metadataArray addObject:metadata];
        [metadata release];
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
                return [self boldString:[tagsArray objectAtIndex:rowIndex]];

            if ([aTableColumn.identifier isEqualToString:@"value"]) {
                NSString *tagName = [tagsArray objectAtIndex:rowIndex];
                if ([tagName isEqualToString:@"Rating"])
                    return [currentMetadata ratingFromIndex:[[tags objectForKey:[tagsArray objectAtIndex:rowIndex]] integerValue]];                    

                return [tags objectForKey:[tagsArray objectAtIndex:rowIndex]];
            }
        }
    }
    return nil;
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    if (!(tableView == movieTitleTable) && width) {
        NSRect r = NSMakeRect(0,0,width,1000.0);
        NSTextFieldCell *cell = [tabCol dataCellForRow:rowIndex];	
        [cell setObjectValue:[tags objectForKey:[tagsArray objectAtIndex:rowIndex]]];
        CGFloat height = [cell cellSizeForBounds:r].height; // Slow
        if (height <= 0)
            height = 17.0; // Ensure miniumum height is 17.0

        return height;
    }
    return 17.0;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([movieTitleTable selectedRow] != -1 && [aNotification object] == movieTitleTable) {
        currentMetadata = [metadataArray objectAtIndex:[movieTitleTable selectedRow]];
        tags = currentMetadata.tagsDict;
        if (tagsArray)
            [tagsArray release];
        tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:[currentMetadata availableMetadata]] retain];
        [metadataTable reloadData];
        [addButton setEnabled:YES];
    }
    else {
        [addButton setEnabled:NO];
    }

}

- (void)tableViewColumnDidResize: (NSNotification* )notification
{
    if ([notification object] == metadataTable) {
        width = [tabCol width];
        [metadataTable noteHeightOfRowsWithIndexesChanged:
         [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [metadataTable numberOfRows])]];
    }
}

- (IBAction) addMetadata: (id) sender
{
    if ([delegate respondsToSelector:@selector(metadataImportDone:)]) 
        [delegate metadataImportDone:[[[metadataArray objectAtIndex:[movieTitleTable selectedRow]] retain] autorelease]];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate metadataImportDone:nil];
}

- (IBAction) tagChimpWebSite: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"http://tagchimp.com/donate/"]];

}

- (void) dealloc
{
    [tabCol release];
    [metadataArray release];
    [detailBoldAttr release];
    [super dealloc];
}

@end
