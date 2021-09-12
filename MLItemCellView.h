/*
 
 Copyright (c) 2013 Max Lungarella <cybrmx@gmail.com>
 
 Created on 24/08/2013.
 
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
#import "MLMedication.h"
#import "MLMainWindowController.h"

@interface MLItemCellView : NSTableCellView <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, weak) IBOutlet NSButtonCell * _Nullable favoritesCheckBox;
@property (nonatomic, weak) IBOutlet NSTableView * _Nullable packagesView;

@property (atomic, nullable) DataObject *selectedMedi;
@property (atomic, nullable) NSString *packagesStr;
@property (atomic) NSInteger numPackages;
@property (atomic) BOOL showContextualMenu;
@property (nonatomic, copy, nullable) void (^onSubtitlePressed)(NSInteger row);

@end

