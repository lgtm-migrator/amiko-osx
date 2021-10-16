/*
 
 Copyright (c) 2017 Max Lungarella <cybrmx@gmail.com>
 
 Created on 28/04/2017.
 
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

#import <Foundation/Foundation.h>

#import "MLInteractionsAdapter.h"
#import "MLMedication.h"

@interface MLInteractionsHtmlView : NSObject

@property (atomic) NSArray *listofSectionIds;
@property (atomic) NSArray *listofSectionTitles;

- (void) pushToMedBasket:(MLMedication *)med;
- (void) removeFromMedBasketForKey:(NSString *)key;
- (void) clearMedBasket;
- (void)fullInteractionsHtml:(MLInteractionsAdapter *)interactions withCompletion:(void (^_Nonnull)(NSString *result))callback;
- (void)medBasketHtmlWithCompletion:(void (^_Nonnull)(NSString * _Nullable result))callback;
- (NSString *) interactionsHtml:(MLInteractionsAdapter *)interactions;
- (NSString *) footNoteHtml;
- (void) sendInteractionNotice;

@end
