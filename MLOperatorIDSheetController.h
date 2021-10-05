/*
 
 Copyright (c) 2017 Max Lungarella <cybrmx@gmail.com>
 
 Created on 06/07/2017.
 
 This file is part of AmiKo for OSX.
 
 AmiKo for OSX is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 ------------------------------------------------------------------------ */

#import <Cocoa/Cocoa.h>

#import "MLSignatureView.h"
#import "MLOperator.h"

@interface MLOperatorIDSheetController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
    @private
    IBOutlet NSWindow *mPanel;
    IBOutlet MLSignatureView *mSignView;
    IBOutlet NSTextField *mTitle;
    IBOutlet NSTextField *mGLN;
    IBOutlet NSTextField *mFamilyName;
    IBOutlet NSTextField *mGivenName;
    IBOutlet NSTextField *mPostalAddress;
    IBOutlet NSTextField *mZipCode;
    IBOutlet NSTextField *mCity;
    IBOutlet NSTextField *mCountry;
    IBOutlet NSTextField *mPhoneNumber;
    IBOutlet NSTextField *mEmailAddress;
    __weak IBOutlet NSTextField *mIBAN;
    __weak IBOutlet NSTextField *mVatNumber;
    __weak IBOutlet NSButton *mSaveButton;
    __weak IBOutlet NSTextField *mZsrNumber;
    __weak IBOutlet NSTextField *mMedidataClientId;
}

- (IBAction) onCancel:(id)sender;
- (IBAction) onSaveOperator:(id)sender;
- (IBAction) onLoadSignature:(id)sender;
- (IBAction) onClearSignature:(id)sender;

- (void) show:(NSWindow *)window;
- (void) remove;
- (NSString *) retrieveCity;
- (MLOperator *) loadOperator;

@end
