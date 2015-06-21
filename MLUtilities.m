/*
 
 Copyright (c) 2015 Max Lungarella <cybrmx@gmail.com>
 
 Created on 01/03/2015.
 
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

#import "MLUtilities.h"

#if defined (AMIKO)
NSString* const APP_NAME = @"AmiKo";
NSString* const APP_ID = @"708142753";
#elif defined (AMIKO_ZR)
NSString* const APP_NAME = @"AmiKo-zR";
NSString* const APP_ID = @"708142753";
#elif defined (AMIKO_DESITIN)
NSString* const APP_NAME = @"AmiKo-Desitin";
NSString* const APP_ID = @"708142753";
#elif defined (COMED)
NSString* const APP_NAME = @"CoMed";
NSString* const APP_ID = @"710472327";
#elif defined (COMED_ZR)
NSString* const APP_NAME = @"CoMed-zR";
NSString* const APP_ID = @"710472327";
#elif defined (COMED_DESITIN)
NSString* const APP_NAME = @"CoMed-Desitin";
NSString* const APP_ID = @"710472327";
#else
NSString* const APP_NAME = @"AmiKo";
NSString* const APP_ID = @"708142753";
#endif

@implementation MLUtilities

+ (NSString *) appOwner
{
    if ([APP_NAME isEqualToString:@"AmiKo"] || [APP_NAME isEqualToString:@"CoMed"])
        return @"ywesee";
    else if ([APP_NAME isEqualToString:@"AmiKo-zR"] || [APP_NAME isEqualToString:@"CoMed-zR"])
        return @"zurrose";
    else if ([APP_NAME isEqualToString:@"AmiKo-Desitin"] || [APP_NAME isEqualToString:@"CoMed-Desitin"])
        return @"desitin";
    return nil;
}

+ (NSString *) appLanguage
{
    if ([APP_NAME isEqualToString:@"AmiKo"] || [APP_NAME isEqualToString:@"AmiKo-zR"] || [APP_NAME isEqualToString:@"AmiKo-Desitin"])
        return @"de";
    else if ([APP_NAME isEqualToString:@"CoMed"] || [APP_NAME isEqualToString:@"CoMed-zR"] || [APP_NAME isEqualToString:@"CoMed-Desitin"])
        return @"fr";
    
    return nil;
}

+ (BOOL) isGermanApp
{
    return [[self appLanguage] isEqualToString:@"de"];
}

+ (BOOL) isFrenchApp
{
    return [[self appLanguage] isEqualToString:@"fr"];
}

+ (NSString *) notSpecified
{
    if ([[self appLanguage] isEqualToString:@"de"])
        return @"k.A.";
    else if ([[self appLanguage] isEqualToString:@"fr"])
        return @"n.s.";
    
    return nil;
}

+ (BOOL) isConnected
{
    NSURL *dummyURL = [NSURL URLWithString:@"http://pillbox.oddb.org"];
    NSData *data = [NSData dataWithContentsOfURL:dummyURL];
    NSLog(@"Ping to pillbox.oddb.org = %lu bytes", (unsigned long)[data length]);
    
    return data!=nil;
}

+ (NSString *) documentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    return [paths lastObject];
}

+ (BOOL) checkFileIsAllowed:(NSString *)name
{
    if ([[self appLanguage] isEqualToString:@"de"]) {
        if ([name isEqualToString:@"amiko_db_full_idx_de.db"]
            || [name isEqualToString:@"amiko_report_de.html"]
            || [name isEqualToString:@"drug_interactions_csv_de.csv"])  {
            return true;
        }
    } else if ([[self appLanguage] isEqualToString:@"fr"]) {
        if ([name isEqualToString:@"amiko_db_full_idx_fr.db"]
            || [name isEqualToString:@"amiko_report_de.html"]
            || [name isEqualToString:@"drug_interactions_csv_fr.csv"])  {
            
            return true;
        }
    }
    
    return false;
}
@end
