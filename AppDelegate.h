//
//  AppDelegate.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrefsController.h"

@interface SBDocumentController : NSDocumentController {
}

@end

@interface AppDelegate : NSObject {

    PrefsController *fPrefs;
	SBDocumentController *documentController;
}

- (IBAction) showPrefsWindow: (id) sender;
- (IBAction) donate:(id)sender;
- (IBAction) help:(id)sender;

@end

