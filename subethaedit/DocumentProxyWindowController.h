//
//  DocumentProxyWindowController.h
//  SubEthaEdit
//
//  Created by Dominik Wagner on Thu Apr 29 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import <AppKit/AppKit.h>

@class TCMMMSession;

@interface DocumentProxyWindowController : NSWindowController {

    IBOutlet NSImageView *O_documentImageView;
    IBOutlet NSImageView *O_userImageView;
    IBOutlet NSTextField *O_documentTitleTextField;
    IBOutlet NSTextField *O_userNameTextField;
    IBOutlet NSTextField *O_statusBarTextField;
    IBOutlet NSView *O_containerView;
    IBOutlet NSView *O_bottomCustomView;
    IBOutlet NSView *O_bottomStatusView;
    IBOutlet NSView *O_bottomDecisionView;

    NSWindow *I_targetWindow;
    TCMMMSession *I_session;

}

- (id)initWithSession:(TCMMMSession *)aSession;

- (IBAction)acceptAction:(id)aSender;

- (void)update;

- (void)setSession:(TCMMMSession *)aSession;
- (void)dissolveToWindow:(NSWindow *)aWindow;
- (void)joinRequestWasDenied;
- (void)invitationWasCanceled;

@end
