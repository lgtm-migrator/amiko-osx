/*
 
 Copyright (c) 2017 Max Lungarella <cybrmx@gmail.com>
 
 Created on 27/07/2017.
 
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

#import "MLPrescriptionItem.h"

@implementation MLPrescriptionItem

@synthesize mid;
@synthesize eanCode;
@synthesize productName;
@synthesize title;
@synthesize owner;
@synthesize price;
@synthesize med;
@synthesize fullPackageInfo, comment;

- (void)importFromDict:(NSDictionary *)dict
{
    title           = [dict objectForKey:KEY_AMK_MED_PROD_NAME];
    fullPackageInfo = [dict objectForKey:KEY_AMK_MED_PACKAGE];
    eanCode         = [dict objectForKey:KEY_AMK_MED_EAN];
    comment         = [dict objectForKey:KEY_AMK_MED_COMMENT];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ title:<%@>, productName:<%@>, _comment:<%@>",
            NSStringFromClass([self class]), title, productName, comment];
}

- (NSString *)title {
    if (title) {
        return title;
    }
    NSArray *titleComponents = [self.fullPackageInfo componentsSeparatedByString:@"["];
    titleComponents = [[titleComponents firstObject] componentsSeparatedByString:@","];
    if ([titleComponents count]) {
        return [titleComponents firstObject];
    }
    return @"";
}

- (NSString *)price {
    NSArray *titleComponents = [self.fullPackageInfo componentsSeparatedByString:@"["];
    titleComponents = [[titleComponents firstObject] componentsSeparatedByString:@","];
    NSString *result = @"";
    if ([titleComponents count]) {
        if ([titleComponents count] > 2) {
            result = [NSString stringWithFormat:@"%@ CHF", titleComponents[2]];
            result = [result stringByReplacingOccurrencesOfString:@"ev.nn.i.H. " withString:@""];
            result = [result stringByReplacingOccurrencesOfString:@"PP " withString:@""];
        }
    }
    return result;
}

@end
