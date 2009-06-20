//
//  SBTableView.h
//  Subler
//
//  Created by Damiano Galassi on 17/06/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SBTableView : NSTableView {
    NSArray *_pasteboardTypes;
}
- (void)keyDown:(NSEvent *)event;
@property(readwrite, retain) NSArray* _pasteboardTypes;
@end

@protocol SBTableViewDelegate
@optional
- (void)_deleteSelectionFromTableView:(NSTableView *)tableView;
- (void)_copySelectionFromTableView:(NSTableView *)tableView;
- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
- (void)_pasteToTableView:(NSTableView *)tableView;

@end
