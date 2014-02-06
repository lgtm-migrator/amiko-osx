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

#import "MLMainWindowController.h"
#import "MLDBAdapter.h"
#import "MLItemCellView.h"
#import "MLSearchWebView.h"
#import "MLDataStore.h"
#import "MLCustomTableRowView.h"

#import <mach/mach.h>
#import <unistd.h>

#if defined (AMIKO)
NSString* const APP_NAME = @"AmiKo";
NSString* const APP_ID = @"708142753";
#elif defined (AMIKO_ZR)
NSString* const APP_NAME = @"AmiKo-zR";
NSString* const APP_ID = @"708142753";
#elif defined (COMED)
NSString* const APP_NAME = @"CoMed";
NSString* const APP_ID = @"710472327";
#elif defined (COMED_ZR)
NSString* const APP_NAME = @"CoMed-zR";
NSString* const APP_ID = @"710472327";
#else
NSString* const APP_NAME = @"AmiKo";
NSString* const APP_ID = @"708142753";
#endif

enum {
    kAips=0, kHospital=1, kFavorites=2
};

enum {
    kTitle=0, kAuthor=1, kAtcCode=2, kRegNr=3, kSubstances=4, kTherapy=5, kWebView=6
};

static NSString *SEARCH_STRING = @"Suche";
static NSString *SEARCH_TITLE = @"Präparat";
static NSString *SEARCH_AUTHOR = @"Inhaber";
static NSString *SEARCH_ATCCODE = @"ATC Code";
static NSString *SEARCH_REGNR = @"Reg. Nr.";
static NSString *SEARCH_SUBSTANCES = @"Wirkstoff";
static NSString *SEARCH_THERAPY = @"Therapie";
static NSString *SEARCH_FACHINFO = @"in Fachinformation";

static NSInteger mUsedDatabase = kAips;
static NSInteger mCurrentSearchState = kTitle;
static NSString *mCurrentSearchKey = @"";

@interface DataObject : NSObject

@property NSString *title;
@property NSString *subTitle;
@property long medId;

@end

@implementation DataObject

@synthesize title;
@synthesize subTitle;
@synthesize medId;

@end

@implementation MLMainWindowController
{
    // Instance variable declarations go here
    MLDBAdapter *mDb;
    
    NSMutableArray *medi;
    NSMutableArray *favoriteKeyData;
    
    NSMutableSet *favoriteMedsSet;
    MLDataStore *favoriteData;    
    
    NSArray *searchResults;
    
    NSArray *listofSectionIds;
    NSArray *listofSectionTitles;
    
    NSProgressIndicator* progressIndicator;
    
    dispatch_queue_t mSearchQueue;
    volatile bool mSearchInProgress;

    float m_alpha;
    float m_delta;
}

@synthesize myView;
@synthesize mySplashScreen;
@synthesize myToolbar;
@synthesize mySearchField;
@synthesize myTableView;
@synthesize mySectionTitles;


- (id) init
{
    // [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]
    // self = [super initWithNibName:@"MLMasterViewController" bundle:nil];
    if ([APP_NAME isEqualToString:@"AmiKo"])
        self = [super initWithWindowNibName:@"MLAmiKoMainWindow"];
    else if ([APP_NAME isEqualToString:@"AmiKo-zR"])
        self = [super initWithWindowNibName:@"MLAmiKozRMainWindow"];
    else if ([APP_NAME isEqualToString:@"CoMed"])
        self = [super initWithWindowNibName:@"MLCoMedMainWindow"];
    else if ([APP_NAME isEqualToString:@"CoMed-zR"])
        self = [super initWithWindowNibName:@"MLCoMedzRMainWindow"];
    else return nil;
    
    if (!self)
        return nil;
    
    // Initialize global serial dispatch queue
    mSearchQueue = dispatch_queue_create("com.ywesee.searchdb", nil);
    mSearchInProgress = false;
    
    if ([[self appLanguage] isEqualToString:@"de"]) {
        SEARCH_STRING = @"Suche";
        SEARCH_TITLE = @"Präparat";
        SEARCH_AUTHOR = @"Inhaber";
        SEARCH_ATCCODE = @"ATC Code";
        SEARCH_REGNR = @"Reg. Nr.";
        SEARCH_SUBSTANCES = @"Wirkstoff";
        SEARCH_THERAPY = @"Therapie";
        SEARCH_FACHINFO = @"in Fachinformation";
    } else if ([[self appLanguage] isEqualToString:@"fr"]) {
        SEARCH_STRING = @"Recherche";
        SEARCH_TITLE = @"Préparation";
        SEARCH_AUTHOR = @"Titulaire";
        SEARCH_ATCCODE = @"Code ATC";
        SEARCH_REGNR = @"No d'autorisation";
        SEARCH_SUBSTANCES = @"Principe Actif";
        SEARCH_THERAPY = @"Thérapie";
        SEARCH_FACHINFO = @"Notice Infopro";
    }
    
    m_alpha = 0.0;
    m_delta = 0.01;
    [[self window] setAlphaValue:1.0];//m_alpha];
    [self fadeInAndShow];
    [[self window] center];
    
    // Allocate some variables
    medi = [NSMutableArray array];
    favoriteKeyData = [NSMutableArray array];
    
    // Open database
    [self openSQLiteDatabase];
    
#ifdef DEBUG
    NSLog(@"Number of records = %ld", (long)[mDb getNumRecords]);
#endif
    
    favoriteData = [[MLDataStore alloc] init];
    [self loadData];
    favoriteMedsSet = [[NSMutableSet alloc] initWithSet:favoriteData.favMedsSet];
    
    // Set default database
    mUsedDatabase = kAips;
    [myToolbar setSelectedItemIdentifier:@"AIPS"];
    
    if ([[self appLanguage] isEqualToString:@"de"])
        [[myToolbar items][3] setLabel:@"Drucken"];
    else if ([[self appLanguage] isEqualToString:@"fr"])
        [[myToolbar items][3] setLabel:@"Imprimer"];
    
    // Set search state
    [self setSearchState:kTitle];
    
    // Register observer to notify successful download of new database
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(finishedDownloading:)
                                                 name:@"MLDidFinishLoading"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowResized:)
                                                 name:NSWindowDidResizeNotification
                                               object:nil];
    [[self window] makeFirstResponder:self];

    /*
    [myToolbar setVisible:NO];
    [[self.window contentView] addSubview:mySplashScreen];
    */
    
    [[self window] setBackgroundColor:[NSColor whiteColor]];
        
    return self;
}

- (void) fadeInAndShow
{
    if (m_alpha<1.0) {
        m_alpha += m_delta;
        [[self window] setAlphaValue:1.0f]; // m_alpha
        
        [NSTimer scheduledTimerWithTimeInterval:0.01
                                         target:self
                                       selector:@selector(fadeInAndShow)
                                       userInfo:nil
                                        repeats:NO];
    } else {
        [[self window] setAlphaValue:1.0];
        // Test
        [self resetDataInTableView];
    }
}

- (void) openSQLiteDatabase
{
    mDb = [[MLDBAdapter alloc] init];
    if ([[self appLanguage] isEqualToString:@"de"]) {
        if (![mDb openDatabase:@"amiko_db_full_idx_de"]) {
            NSLog(@"No German database!");
            mDb = nil;
        }
    } else if ([[self appLanguage] isEqualToString:@"fr"]) {
        if (![mDb openDatabase:@"amiko_db_full_idx_fr"]) {
            NSLog(@"No French database!");
            mDb = nil;
        }
    }
}

- (void) finishedDownloading:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"MLDidFinishLoading"]) {
        if (mDb!=nil) {
            // Close database
            [mDb closeDatabase];
            // Re-open database
            [self openSQLiteDatabase];
            // Reload table
            NSInteger _mySearchState = mCurrentSearchState;
            NSString *_mySearchKey = mCurrentSearchKey;
            [self resetDataInTableView];
            mCurrentSearchState = _mySearchState;
            mCurrentSearchKey = _mySearchKey;
            // Display friendly message
            NSBeep();
            long numSearchRes = [searchResults count];
            
            NSAlert *alert = [[NSAlert alloc] init];
            
            [alert addButtonWithTitle:@"OK"];
            if ([[self appLanguage] isEqualToString:@"de"]) {
                [alert setMessageText:@"AIPS Datenbank aktualisiert!"];
                [alert setInformativeText:[NSString stringWithFormat:@"Die Datenbank enthält %ld Fachinfos.", numSearchRes]];
            } else if ([[self appLanguage] isEqualToString:@"fr"]) {
                [alert setMessageText:@"Banque des donnees AIPS mises à jour!"];
                [alert setInformativeText:[NSString stringWithFormat:@"La banque des données contien %ld notices infopro.", numSearchRes]];
            }
            [alert setAlertStyle:NSInformationalAlertStyle];
            
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:self
                             didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                                contextInfo:nil];
        }
    }
}


- (void) alertDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode==NSAlertFirstButtonReturn) {
        NSLog(@"Database successfully updated!");
        // Resume table
        [self restoreDataInTableView];
    }
}

- (void) resetDataInTableView
{
    // Reset search state
    [self setSearchState:kTitle];
    
    searchResults = [self searchAipsDatabaseWith:@""];
    if (searchResults) {
        [self updateTableView];
        [self.myTableView reloadData];
        [self.myTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1)];
    }
}

- (void) restoreDataInTableView
{
    // Restore search state
    [self setSearchState:mCurrentSearchState];
    // Search
    if (mCurrentSearchState!=kWebView) {
        if (mUsedDatabase==kAips) {
            searchResults = [self searchAipsDatabaseWith:mCurrentSearchKey];
        }
        else if (mUsedDatabase==kFavorites) {
            searchResults = [self retrieveAllFavorites];
        }
        if (searchResults) {
            [[mySearchField cell] setStringValue:mCurrentSearchKey];
            [self updateTableView];
            [self.myTableView reloadData];
        }
    } else {
        [[mySearchField cell] setStringValue:mCurrentSearchKey];
    }
}

- (void) awakeFromNib
{
    // Important for capturing actions from menus
    // [[self window] makeFirstResponder:self];
    
    // Problem with this function is that it is called multiple times...
}

- (void) windowResized: (NSNotification *)notification;
{
    /*
     [self.mySplashScreen removeFromSuperview];
     [myToolbar setVisible:YES];
     */
}

- (NSString *) appOwner
{
    if ([APP_NAME isEqualToString:@"AmiKo"]
        || [APP_NAME isEqualToString:@"CoMed"])
        return @"ywesee";
    else if ([APP_NAME isEqualToString:@"AmiKo-zR"]
             || [APP_NAME isEqualToString:@"CoMed-zR"])
        return @"zurrose";
    
    return nil;
}

- (NSString *) appLanguage
{
    if ([APP_NAME isEqualToString:@"AmiKo"]
        || [APP_NAME isEqualToString:@"AmiKo-zR"])
        return @"de";
    else if ([APP_NAME isEqualToString:@"CoMed"]
             || [APP_NAME isEqualToString:@"CoMed-zR"])
        return @"fr";
    
    return nil;
}

- (NSString *) notSpecified
{
    if ([APP_NAME isEqualToString:@"AmiKo"]
        || [APP_NAME isEqualToString:@"AmiKo-zR"])
        return @"k.A.";
    else if ([APP_NAME isEqualToString:@"CoMed"]
             || [APP_NAME isEqualToString:@"CoMed-zR"])
        return @"n.s.";
    
    return nil;
}

- (IBAction) tappedOnStar: (id)sender
{
    NSInteger row = [self.myTableView rowForView:sender];
#ifdef DEBUG
    NSLog(@"Tapped on star: %ld", row);
#endif
    NSString *medRegnrs = [NSString stringWithString:[favoriteKeyData objectAtIndex:row]];
    
    if ([favoriteMedsSet containsObject:medRegnrs])
        [favoriteMedsSet removeObject:medRegnrs];
    else
        [favoriteMedsSet addObject:medRegnrs];
     
     favoriteData = [MLDataStore initWithFavMedsSet:favoriteMedsSet];
     [self saveData];
}

- (IBAction) searchNow: (id)sender
{
    NSString *searchText = [mySearchField stringValue];
    
    if (mCurrentSearchState != kWebView ) {
        searchResults = [NSArray array];
        
        // MLMainWindowController* __weak weakSelf = self;  // best solution but works only for > 10.8
        MLMainWindowController* __unsafe_unretained weakSelf = self; // works also in 10.7 (Lion)
        
        // dispatch_queue_t search_queue = dispatch_queue_create("com.ywesee.searchdb", nil);
        dispatch_async(mSearchQueue, ^(void) {
            MLMainWindowController* scopeSelf = weakSelf;
            while (mSearchInProgress) {
                [NSThread sleepForTimeInterval:0.005];  // Wait for 5ms
            }
            if (!mSearchInProgress) {
                @synchronized(self) {
                    mSearchInProgress = true;
                }
                if ([searchText length]>0)
                    searchResults = [scopeSelf searchAipsDatabaseWith:searchText];
                else {
                    if (mUsedDatabase == kFavorites)
                        searchResults = [scopeSelf retrieveAllFavorites];
                }
                // Update tableview
                dispatch_async(dispatch_get_main_queue(), ^{
                    [scopeSelf updateTableView];
                    [self.myTableView reloadData];
                    @synchronized(self) {
                        mSearchInProgress = false;
                    }
                });
            }
        });
    } else {
        if ([searchText length] > 2)
            [myWebView highlightAllOccurencesOfString:searchText];
        else
            [myWebView removeAllHighlights];
    }
}

- (IBAction) onButtonPressed: (id)sender
{  
    NSButton *btn = (NSButton *)sender;
    
    switch (btn.tag) {
        case 0:
            [self setSearchState:kTitle];
            break;
        case 1:
            [self setSearchState:kAuthor];
            break;
        case 2:
            [self setSearchState:kAtcCode];
            break;
        case 3:
            [self setSearchState:kRegNr];
            break;
        case 4:
            [self setSearchState:kSubstances];
            break;
        case 5:
            [self setSearchState:kTherapy];
            break;
    }
    
    if (searchResults) {
        [self updateTableView];
        [self.myTableView reloadData];
    }
}

- (IBAction) toolbarAction: (id)sender
{
    [self launchProgressIndicator];
    
    NSToolbarItem *item = (NSToolbarItem *)sender;
    [self performSelector:@selector(switchDatabases:) withObject:item afterDelay:0.01];
}

- (IBAction) printDocument:(id)sender
{
    WebFrame *webFrame = [myWebView mainFrame];
    WebFrameView *webFrameView = [webFrame frameView];
    NSView <WebDocumentView> *webDocumentView = [webFrameView documentView];
    
    NSPrintInfo *printInfo = [[NSPrintInfo alloc] init];
    [printInfo setOrientation:NSPortraitOrientation];
    [printInfo setHorizontalPagination:NSFitPagination];
    NSPrintOperation *printJob = [NSPrintOperation printOperationWithView:webDocumentView printInfo:printInfo];
    // [printJob setPrintPanel:myPrintPanel]; --> needs to be subclassed
    [printJob runOperation];
}

- (IBAction) printSearchResult: (id)sender
{
    NSPrintInfo *printInfo = [[NSPrintInfo alloc] init];
    [printInfo setOrientation:NSPortraitOrientation];
    [printInfo setHorizontalPagination:NSFitPagination];
    NSPrintOperation *printJob = [NSPrintOperation printOperationWithView:myTableView printInfo:printInfo];
    [printJob runOperation];
}

- (IBAction) updateAipsDatabase:(id)sender
{
    // Update database
    if ([[self appLanguage] isEqualToString:@"de"])
        [mDb updateDatabase:@"de" for:[self appOwner]];
    else if ([[self appLanguage] isEqualToString:@"fr"])
        [mDb updateDatabase:@"fr" for:[self appOwner]];
}

- (IBAction) showAboutFile:(id)sender
{
    // A. Check first users documents folder
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // Get documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths lastObject];
    if ([[self appLanguage] isEqualToString:@"de"]) {
        NSString *filePath = [[documentsDir stringByAppendingPathComponent:@"amiko_report_de"] stringByAppendingPathExtension:@"html"];
        if ([fileManager fileExistsAtPath:filePath]) {
            // Starts Safari            
            [[NSWorkspace sharedWorkspace] openFile:filePath];
        } else {
            NSURL * aboutFile = [[NSBundle mainBundle] URLForResource:@"amiko_report_de" withExtension:@"html"];
            // Starts Safari
            [[NSWorkspace sharedWorkspace] openURL:aboutFile];
        }
    } else if ([[self appLanguage] isEqualToString:@"fr"]) {
        NSString *filePath = [[documentsDir stringByAppendingPathComponent:@"amiko_report_fr"] stringByAppendingPathExtension:@"html"];
        if ([fileManager fileExistsAtPath:filePath]) {
            // Starts Safari
            [[NSWorkspace sharedWorkspace] openFile:filePath];
        } else {
            NSURL * aboutFile = [[NSBundle mainBundle] URLForResource:@"amiko_report_fr" withExtension:@"html"];
            // Starts Safari
            [[NSWorkspace sharedWorkspace] openURL:aboutFile];
        }
    }
}

// A small custom about box
- (IBAction) showAboutPanel:(id)sender
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *creditsPath = nil;
    if ([[self appLanguage] isEqualToString:@"de"])
        creditsPath = [mainBundle pathForResource:@"Credits-de" ofType:@"rtf"];
    else if ([[self appLanguage] isEqualToString:@"fr"])
        creditsPath = [mainBundle pathForResource:@"Credits-fr" ofType:@"rtf"];
    NSAttributedString *credits = [[NSAttributedString alloc] initWithPath:creditsPath documentAttributes:nil];
    
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"dd.MM.yyyy"];
    NSString *compileDate = [dateFormat stringFromDate:today];
    
    NSString *versionString = [NSString stringWithFormat:@"%@", compileDate];
   
    NSDictionary *optionsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                 credits, @"Credits",
                                 [mainBundle objectForInfoDictionaryKey:@"CFBundleName"], @"ApplicationName",
                                 [mainBundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"], @"Copyright",
                                 [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], @"ApplicationVersion",
                                 versionString, @"Version",
                                 nil];
    
    [NSApp orderFrontStandardAboutPanelWithOptions:optionsDict];
}

- (IBAction) sendFeedback:(id)sender
{
    NSString *subject = [NSString stringWithFormat:@"%@ Feedback", APP_NAME];
    NSString *encodedSubject = [NSString stringWithFormat:@"mailto:zdavatz@ywesee.com?subject=%@", [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *helpFile = [NSURL URLWithString:encodedSubject];
    // Starts mail client
    [[NSWorkspace sharedWorkspace] openURL:helpFile];
}

- (IBAction) shareApp:(id)sender
{
    // Starts mail client
    NSString* subject = [NSString stringWithFormat:@"%@ OS X", APP_NAME];
    NSString* body = nil;
    if ([[self appLanguage] isEqualToString:@"de"])
        body = [NSString stringWithFormat:@"%@ OS X: Schweizer Arzneimittelkompendium\r\n\n"
                "Get it now: https://itunes.apple.com/us/app/amiko/id%@?mt=12\r\n\nEnjoy!\r\n", APP_NAME, APP_ID];
    else if ([[self appLanguage] isEqualToString:@"fr"])
        body = [NSString stringWithFormat:@"%@ OS X: Compendium des Médicaments Suisse\r\n\n"
                "Get it now: https://itunes.apple.com/us/app/amiko/id%@?mt=12\r\n\nEnjoy!\r\n", APP_NAME, APP_ID];
    NSString *encodedSubject = [NSString stringWithFormat:@"subject=%@", [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSString *encodedBody = [NSString stringWithFormat:@"body=%@", [body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSString *encodedURLString = [NSString stringWithFormat:@"mailto:?%@&%@", encodedSubject, encodedBody];

    NSURL *mailtoURL = [NSURL URLWithString:encodedURLString];
    
    [[NSWorkspace sharedWorkspace] openURL:mailtoURL];
}

- (IBAction) rateApp:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"macappstore://itunes.apple.com/app/id%@?mt=12", APP_ID]]];
}

- (void) showHelp: (id)sender
{
    // Starts Safari
    if ([[self appOwner] isEqualToString:@"zurrose"]) {
        NSURL *helpFile = [NSURL URLWithString:@"http://www.zurrose.ch/amiko"];
        [[NSWorkspace sharedWorkspace] openURL:helpFile];
    } else if ([[self appOwner] isEqualToString:@"ywesee"]) {
        NSURL *helpFile = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/us/app/amiko/id%@?mt=12", APP_ID]];
        [[NSWorkspace sharedWorkspace] openURL:helpFile];
    }
}

- (void) launchProgressIndicator
{
    if (progressIndicator!=nil) {
        [progressIndicator stopAnimation:self];
        [progressIndicator removeFromSuperview];
    }
    
    CGFloat viewWidth = myView.bounds.size.width;
    CGFloat viewHeight = myView.bounds.size.height;
    progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(viewWidth/2-16, viewHeight/2-16, 32, 32)];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [progressIndicator startAnimation:self];
    
    [myView addSubview:progressIndicator];
}

- (void) stopProgressIndicator
{
    [progressIndicator stopAnimation:self];
    [progressIndicator removeFromSuperview];
}

- (void) switchDatabases: (NSToolbarItem *)item
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    switch (item.tag) {
        case 0:
        {
            NSLog(@"AIPS Database");
            mUsedDatabase = kAips;
            //
            searchResults = [NSArray array];
            // MLMainWindowController* __weak weakSelf = self;
            MLMainWindowController* __unsafe_unretained weakSelf = self;
            //
            // dispatch_queue_t search_queue = dispatch_queue_create("com.ywesee.searchdb", nil);
            dispatch_async(mSearchQueue, ^(void) {
                MLMainWindowController* scopeSelf = weakSelf;
                while (mSearchInProgress) {
                   [NSThread sleepForTimeInterval:0.005];  // Wait for 5ms
                }
                if (!mSearchInProgress) {
                    @synchronized(self) {
                        mSearchInProgress = true;
                    }
                    mCurrentSearchState = kTitle;
                    searchResults = [scopeSelf searchAipsDatabaseWith:@""];
                
                    // Update tableview
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [scopeSelf updateTableView];
                        [self.myTableView reloadData];
                        @synchronized(self) {
                            mSearchInProgress = false;
                        }
                    });
                }
            });
            break;
        }
        case 1:
        {
            NSLog(@"Favorites");
            mUsedDatabase = kFavorites;
            //
            searchResults = [NSArray array];
            // MLMainWindowController* __weak weakSelf = self;
            MLMainWindowController* __unsafe_unretained weakSelf = self;
            //
            // dispatch_queue_t search_queue = dispatch_queue_create("com.ywesee.searchdb", nil);
            dispatch_async(mSearchQueue, ^(void) {
                MLMainWindowController* scopeSelf = weakSelf;
                while (mSearchInProgress) {
                   [NSThread sleepForTimeInterval:0.005];  // Wait for 5ms
                }
                if (!mSearchInProgress) {
                    @synchronized(self) {
                        mSearchInProgress = true;
                    }
                    mCurrentSearchState = kTitle;
                    searchResults = [scopeSelf retrieveAllFavorites];

                    // Update tableview
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [scopeSelf updateTableView];
                        [self.myTableView reloadData];
                        @synchronized(self) {
                            mSearchInProgress = false;
                        }
                    });
                }
            });
            break;
        }
        default:
            break;
    }
}

- (NSArray *) retrieveAllFavorites
{
    NSMutableArray *medList = [NSMutableArray array];

#ifdef DEBUG
    NSDate *startTime = [NSDate date];
#endif
    
    if (mDb!=nil) {
        for (NSString *regnrs in favoriteMedsSet) {
            NSArray *med = [mDb searchRegNr:regnrs];
            [medList addObject:med[0]];
        }
        
#ifdef DEBUG
        NSDate *endTime = [NSDate date];
        NSTimeInterval execTime = [endTime timeIntervalSinceDate:startTime];
        NSLog(@"%ld Favoriten in %dms", [medList count], (int)(1000*execTime+0.5));
#endif
        return medList;
    }
    return nil;
}

- (void) saveData
{
    NSString *path = @"~/Library/Preferences/data";
    path = [path stringByExpandingTildeInPath];
    
    NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];
    
    [rootObject setValue:favoriteData forKey:@"kFavMedsSet"];
    
    // Save contents of rootObject by key, value must conform to NSCoding protocolw
    [NSKeyedArchiver archiveRootObject:rootObject toFile:path];
}

- (void) loadData
{
    NSString *path = @"~/Library/Preferences/data";
    path = [path stringByExpandingTildeInPath];
    
    // Retrieves unarchived dictionary into rootObject
    NSMutableDictionary *rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    
    if ([rootObject valueForKey:@"kFavMedsSet"]) {
        favoriteData = [rootObject valueForKey:@"kFavMedsSet"];
    }
}

- (void) setSearchState: (NSInteger)searchState
{
    switch (searchState) {
        case kTitle:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kTitle;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_TITLE]];
             break;
        case kAuthor:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kAuthor;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_AUTHOR]];
            break;
        case kAtcCode:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kAtcCode;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_ATCCODE]];
            break;
        case kRegNr:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kRegNr;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_REGNR]];
            break;
        case kSubstances:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kSubstances;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_SUBSTANCES]];
            break;
        case kTherapy:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kTherapy;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_THERAPY]];
            break;
        case kWebView:
            [[mySearchField cell] setStringValue:@""];
            mCurrentSearchState = kWebView;
            [[mySearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ %@", SEARCH_STRING, SEARCH_FACHINFO]];
            break;
    }
    mCurrentSearchState = searchState;
}

- (NSArray *) searchAipsDatabaseWith:(NSString *)searchQuery
{    
    NSArray *searchRes = [NSArray array];
    
#ifdef DEBUG
    NSDate *startTime = [NSDate date];
#endif
    
    if (mCurrentSearchState == kTitle) {
        searchRes = [mDb searchTitle:searchQuery];
    }
    else if (mCurrentSearchState == kAuthor) {
        searchRes = [mDb searchAuthor:searchQuery];
    }
    else if (mCurrentSearchState == kAtcCode) {
        searchRes = [mDb searchATCCode:searchQuery];
    }
    else if (mCurrentSearchState == kRegNr) {
        searchRes = [mDb searchRegNr:searchQuery];
    }
    else if (mCurrentSearchState == kSubstances) {
        searchRes = [mDb searchIngredients:searchQuery];
    }
    else if (mCurrentSearchState == kTherapy) {
        searchRes = [mDb searchApplication:searchQuery];
    }

    mCurrentSearchKey = searchQuery;
    
#ifdef DEBUG    
    NSDate *endTime = [NSDate date];
    NSTimeInterval execTime = [endTime timeIntervalSinceDate:startTime];

    int timeForSearch_ms = (int)(1000*execTime+0.5);
    NSLog(@"%ld Treffer in %dms", (unsigned long)[searchRes count], timeForSearch_ms);
#endif
    return searchRes;
}

- (void) addTitle: (NSString *)title andPackInfo: (NSString *)packinfo andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![title isEqual:[NSNull null]])
        m.title = title;
    else
        m.title = [self notSpecified]; // @"k.A.";
    if (![packinfo isEqual:[NSNull null]]) {
        if ([packinfo length]>0)
            m.subTitle = packinfo;
        else
            m.subTitle = [self notSpecified]; // @"k.A.";
    } else
        m.subTitle = [self notSpecified]; // @"k.A.";
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) addTitle: (NSString *)title andAuthor: (NSString *)author andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![title isEqual:[NSNull null]])
        m.title = title;
    else
        m.title = [self notSpecified]; // @"k.A.";
    if (![author isEqual:[NSNull null]]) {
        if ([author length]>0)
            m.subTitle = author;
        else
            m.subTitle = [self notSpecified]; // @"k.A.";
    } else
        m.subTitle = [self notSpecified]; // @"k.A.";
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) addTitle: (NSString *)title andAtcCode: (NSString *)atccode andAtcClass: (NSString *)atcclass andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![title isEqual:[NSNull null]])
        m.title = title;
    else
        m.title = [self notSpecified]; // @"k.A.";
    NSArray *m_atc = [atccode componentsSeparatedByString:@";"];
    NSArray *m_class = [atcclass componentsSeparatedByString:@";"];
    NSMutableString *m_atccode_str = nil;
    NSMutableString *m_atcclass_str = nil;
    if ([m_atc count] > 1) {
        if (![[m_atc objectAtIndex:0] isEqual:nil])
            m_atccode_str = [NSMutableString stringWithString:[m_atc objectAtIndex:0]];
        if (![[m_atc objectAtIndex:1] isEqual:nil])
            m_atcclass_str = [NSMutableString stringWithString:[m_atc objectAtIndex:1]];
    }
    NSMutableString *m_atcclass = nil;
    if ([m_class count] == 2)
        m_atcclass = [NSMutableString stringWithString:[m_class objectAtIndex:0]];
    else if ([m_class count] == 3)
        m_atcclass = [NSMutableString stringWithString:[m_class objectAtIndex:1]];
    if ([m_atccode_str isEqual:[NSNull null]])
        [m_atccode_str setString:[self notSpecified]];
    if ([m_atcclass_str isEqual:[NSNull null]])
        [m_atcclass_str setString:[self notSpecified]];
    if ([m_atcclass isEqual:[NSNull null]])
        [m_atcclass setString:[self notSpecified]];
    m.subTitle = [NSString stringWithFormat:@"%@ - %@\n%@", m_atccode_str, m_atcclass_str, m_atcclass];
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) addTitle: (NSString *)title andRegnrs: (NSString *)regnrs andAuthor: (NSString *)author andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![title isEqual:[NSNull null]])
        m.title = title;
    else
        m.title = [self notSpecified]; // @"k.A.";
    NSMutableString *m_regnrs = [NSMutableString stringWithString:regnrs];
    NSMutableString *m_auth = [NSMutableString stringWithString:author];
    if ([m_regnrs isEqual:[NSNull null]])
        [m_regnrs setString:[self notSpecified]];
    if ([m_auth isEqual:[NSNull null]])
        [m_auth setString:[self notSpecified]];
    m.subTitle = [NSString stringWithFormat:@"%@ - %@", m_regnrs, m_auth];
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) addSubstances: (NSString *)substances andTitle: (NSString *)title andAuthor: (NSString *)author andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![substances isEqual:[NSNull null]]) {
        // Unicode for character 'alpha' = &#593;
        substances = [substances stringByReplacingOccurrencesOfString:@"&alpha;" withString:@"ɑ"];
        m.title = substances;
    }
    else
        m.title = [self notSpecified]; // @"k.A.";
    NSMutableString *m_title = [NSMutableString stringWithString:title];
    NSMutableString *m_auth = [NSMutableString stringWithString:author];
    if ([m_title isEqual:[NSNull null]])
        [m_title setString:[self notSpecified]];
    if ([m_auth isEqual:[NSNull null]])
        [m_auth setString:[self notSpecified]];
    m.subTitle = [NSString stringWithFormat:@"%@ - %@", m_title, m_auth];
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) addTitle: (NSString *)title andApplications: (NSString *)applications andMedId: (long)medId
{
    DataObject *m = [[DataObject alloc] init];
    
    if (![title isEqual:[NSNull null]])
        m.title = title;
    else
        m.title = [self notSpecified]; // @"k.A.";
    NSArray *m_applications = [applications componentsSeparatedByString:@";"];
    NSMutableString *m_swissmedic = nil;
    NSMutableString *m_bag = nil;
    if ([m_applications count]>0) {
        if (![[m_applications objectAtIndex:0] isEqual:nil])
            m_swissmedic = [NSMutableString stringWithString:[m_applications objectAtIndex:0]];
        if ([m_applications count]>1) {
            if (![[m_applications objectAtIndex:1] isEqual:nil])
                m_bag = [NSMutableString stringWithString:[m_applications objectAtIndex:1]];
        }
    }
    if ([m_swissmedic isEqual:[NSNull null]])
        [m_swissmedic setString:[self notSpecified]];
    if ([m_bag isEqual:[NSNull null]])
        [m_bag setString:[self notSpecified]]; // @"k.A.";
    m.subTitle = [NSString stringWithFormat:@"%@\n%@", m_swissmedic, m_bag];
    m.medId = medId;
    
    [medi addObject:m];
}

- (void) updateTableView
{
    if (searchResults) {
        
        if (medi != nil)
            [medi removeAllObjects];
        
        if (favoriteKeyData != nil)
            [favoriteKeyData removeAllObjects];
        
        if (mCurrentSearchState == kTitle) {
            if (mUsedDatabase == kAips) {
                for (MLMedication *m in searchResults) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addTitle:m.title andPackInfo:m.packInfo andMedId:m.medId];
                    }
                }
            }
            else if (mUsedDatabase == kFavorites) {
                for (MLMedication *m in searchResults) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addTitle:m.title andPackInfo:m.packInfo andMedId:m.medId];
                        }
                    }
                }
            }
        }  else if (mCurrentSearchState == kAuthor) {
            for (MLMedication *m in searchResults) {
                if (mUsedDatabase == kAips) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addTitle:m.title andAuthor:m.auth andMedId:m.medId];
                    }
                }
                else if (mUsedDatabase == kFavorites) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addTitle:m.title andAuthor:m.auth andMedId:m.medId];
                        }
                    }
                }
            }
        }
        else if (mCurrentSearchState == kAtcCode) {
            for (MLMedication *m in searchResults) {
                if (mUsedDatabase == kAips) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addTitle:m.title andAtcCode:m.atccode andAtcClass:m.atcClass andMedId:m.medId];
                    }
                }
                else if (mUsedDatabase == kFavorites) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addTitle:m.title andAtcCode:m.atccode andAtcClass:m.atcClass andMedId:m.medId];
                        }
                    }
                }
            }
        }
        else if (mCurrentSearchState == kRegNr) {
            for (MLMedication *m in searchResults) {
                if (mUsedDatabase == kAips) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addTitle:m.title andRegnrs:m.regnrs andAuthor:m.auth andMedId:m.medId];
                    }
                }
                else if (mUsedDatabase == kFavorites) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addTitle:m.title andRegnrs:m.regnrs andAuthor:m.auth andMedId:m.medId];
                        }
                    }
                }
            }
        }
        else if (mCurrentSearchState == kSubstances) {
            for (MLMedication *m in searchResults) {
                if (mUsedDatabase == kAips) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addSubstances:m.substances andTitle:m.title andAuthor:m.auth andMedId:m.medId];
                    }
                }
                else if (mUsedDatabase == kFavorites) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addSubstances:m.substances andTitle:m.title andAuthor:m.auth andMedId:m.medId];
                        }
                    }
                }
            }
        }
        else if (mCurrentSearchState == kTherapy) {
            for (MLMedication *m in searchResults) {
                if (mUsedDatabase == kAips) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        [favoriteKeyData addObject:m.regnrs];
                        [self addTitle:m.title andApplications:m.application andMedId:m.medId];
                    }
                }
                else if (mUsedDatabase == kFavorites) {
                    if (![m.regnrs isEqual:[NSNull null]]) {
                        if ([favoriteMedsSet containsObject:m.regnrs]) {
                            [favoriteKeyData addObject:m.regnrs];
                            [self addTitle:m.title andApplications:m.application andMedId:m.medId];
                        }
                    }
                }
            }
        }

        // Sort alphabetically
        if (mUsedDatabase == kFavorites) {            
            NSSortDescriptor *titleSort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
            [medi sortUsingDescriptors:[NSArray arrayWithObject:titleSort]];
        }        
    }
    
    [self stopProgressIndicator];
}

/** NSTableViewDataSource
 */
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{    
    if (tableView == self.myTableView) {
        if (mUsedDatabase == kAips) {
            // NSLog(@"table entries (aips): %ld", (unsigned long)[medi count]);
            return [medi count];
        } else if (mUsedDatabase == kFavorites) {
            // NSLog(@"table entries (favs): %ld", (unsigned long)[favoriteKeyData count]);
            return [favoriteKeyData count];
        }
    } else if (tableView == self.mySectionTitles) {
        // NSLog(@"num sections: %ld", (unsigned long)[listofSectionTitles count]);
        return [listofSectionTitles count];
    }

    return 0;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    MLCustomTableRowView *rowView = [[MLCustomTableRowView alloc] initWithFrame:NSZeroRect];
    [rowView setRowIndex:row];
    
    return rowView;
}

/** NSTableViewDataDelegate
 */
- (NSView *) tableView: (NSTableView *)tableView viewForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row
{
    if (tableView == self.myTableView) {
        // Get new CellView
        MLItemCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

        if ([tableColumn.identifier isEqualToString:@"MLSimpleCell"]) {
            cellView.textField.stringValue = [medi[row] title];
            cellView.detailTextField.stringValue = [medi[row] subTitle];
            // Check if cell.textLabel.text is in starred NSSet
            NSString *regnrStr = favoriteKeyData[row];
            if ([favoriteMedsSet containsObject:regnrStr])
                cellView.favoritesCheckBox.state = 1;
            else
                cellView.favoritesCheckBox.state = 0;
            cellView.favoritesCheckBox.tag = row;

            // Set colors
            if ([cellView.detailTextField.stringValue rangeOfString:@", O]"].location == NSNotFound) {
                if ([cellView.detailTextField.stringValue rangeOfString:@", G]"].location == NSNotFound) {
                    // Anything else ...
                    [cellView setDetailTextColor:[NSColor grayColor]];
                } else {
                    // Generika
                    [cellView setDetailTextColor:[NSColor colorWithCalibratedRed:0.0 green:0.8 blue:0.2 alpha:1.0]];
                }
            } else {
                // Original
                [cellView setDetailTextColor:[NSColor redColor]];
            }
            
            return cellView;
        }
    } else if (tableView == mySectionTitles) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
        if ([tableColumn.identifier isEqualToString:@"MLSimpleCell"])
        {
            cellView.textField.stringValue = listofSectionTitles[row];
            return cellView;
        }
    }
    return nil;
}

- (void) tableViewSelectionDidChange: (NSNotification *)notification
{    
    if ([notification object] == self.myTableView) {
                
        NSInteger row = [[notification object] selectedRow];
        long mId = [medi[row] medId];
    
        // Get medi
        MLMedication *med = [mDb searchId:mId];
    
        // Load style sheet from file
        NSString *amikoCssPath = [[NSBundle mainBundle] pathForResource:@"amiko_stylesheet" ofType:@"css"];
        NSString *amikoCss = nil;
        if (amikoCssPath)
            amikoCss = [NSString stringWithContentsOfFile:amikoCssPath encoding:NSUTF8StringEncoding error:nil];
        else
            amikoCss = [NSString stringWithString:med.styleStr];
        
        // Extract html string
        NSString *htmlStr = [NSString stringWithFormat:@"<head><style>%@</style></head>%@", amikoCss, med.contentStr];
        NSURL *mainBundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        [[myWebView mainFrame] loadHTMLString:htmlStr baseURL:mainBundleURL];
        [self setSearchState:kWebView];
    
        [[myWebView preferences] setDefaultFontSize:14];
    
        NSTableRowView *myRowView = [self.myTableView rowViewAtRow:row makeIfNecessary:NO];
        [myRowView setEmphasized:YES];
        
        // Extract section ids
        listofSectionIds = [med.sectionIds componentsSeparatedByString:@","];
        // Extract section titles
        // listofSectionTitles = [SectionTitle_DE componentsSeparatedByString:@";"];
        listofSectionTitles = [med.sectionTitles componentsSeparatedByString:@";"];
        //
        [mySectionTitles reloadData];
    } else if ([notification object] == mySectionTitles) {
        NSInteger row = [[notification object] selectedRow];
        
        NSString *javaScript = [NSString stringWithFormat:@"window.location.hash='#%@'", listofSectionIds[row]];
        [myWebView stringByEvaluatingJavaScriptFromString:javaScript];
        
    }
    
#ifdef DEBUG
    report_memory();
#endif
}

/*
- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
    
}

- (void) tableViewColumnDidResize:(NSNotification *)notification
{
    NSLog(@"Column resized");
}
*/

#define PADDING 5.0f
- (CGFloat) tableView: (NSTableView *)tableView heightOfRow: (NSInteger)row
{
    if (tableView == self.myTableView) {
        NSString *text = [medi[row] title];
        NSString *subText = [medi[row] subTitle];
    
        NSFont *textFont = [NSFont boldSystemFontOfSize:13.0f];
        CGSize textSize = NSSizeFromCGSize([text sizeWithAttributes:[NSDictionary dictionaryWithObject:textFont
                                                                                                forKey:NSFontAttributeName]]);
        NSFont *subTextFont = [NSFont boldSystemFontOfSize:11.0f];
        CGSize subTextSize = NSSizeFromCGSize([subText sizeWithAttributes:[NSDictionary dictionaryWithObject:subTextFont
                                                                                                      forKey:NSFontAttributeName]]);
        return (textSize.height + subTextSize.height + PADDING);
    } else if (tableView == mySectionTitles) {
        NSString *text = listofSectionTitles[row];
        NSFont *textFont = [NSFont boldSystemFontOfSize:11.0f];
        CGSize textSize = NSSizeFromCGSize([text sizeWithAttributes:[NSDictionary dictionaryWithObject:textFont
                                                                                                forKey:NSFontAttributeName]]);        
        return (textSize.height + PADDING);
    }
    
    return 0.0f;
}

void report_memory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if( kerr == KERN_SUCCESS ) {
        NSLog(@"Memory in use (in bytes): %lu", info.resident_size);
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }
}

@end
