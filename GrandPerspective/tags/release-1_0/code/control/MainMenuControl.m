#import "MainMenuControl.h"

#import "DirectoryItem.h"

#import "ControlConstants.h"

#import "DirectoryViewControl.h"
#import "DirectoryViewControlSettings.h"
#import "SaveImageDialogControl.h"
#import "EditFilterWindowControl.h"
#import "PreferencesPanelControl.h"

#import "ItemPathModel.h"
#import "ItemPathModelView.h"
#import "TreeFilter.h"
#import "TreeWriter.h"
#import "TreeReader.h"
#import "TreeContext.h"

#import "WindowManager.h"

#import "VisibleAsynchronousTaskManager.h"
#import "ScanProgressPanelControl.h"
#import "ScanTaskInput.h"
#import "ScanTaskExecutor.h"
#import "FilterProgressPanelControl.h"
#import "FilterTaskInput.h"
#import "FilterTaskExecutor.h"
#import "ReadProgressPanelControl.h"
#import "ReadTaskInput.h"
#import "ReadTaskExecutor.h"
#import "WriteProgressPanelControl.h"
#import "WriteTaskInput.h"
#import "WriteTaskExecutor.h"

#import "FileItemTest.h"
#import "FileItemTestRepository.h"

#import "UniformTypeRanking.h"
#import "UniformTypeInventory.h"


static int  nextFilterId = 1;


@interface ModalityTerminator : NSObject {
}

- (void) abortModalAction: (NSNotification *)notification;
- (void) stopModalAction: (NSNotification *)notification;

@end


@interface ReadTaskCallback : NSObject {
  WindowManager  *windowManager;
  ReadTaskInput  *taskInput;
}

- (id) initWithWindowManager: (WindowManager *)windowManager 
         readTaskInput: (ReadTaskInput *)taskInput;

- (void) readTaskCompleted: (id) result;

@end // @interface ReadTaskCallback


@interface WriteTaskCallback : NSObject {
  WriteTaskInput  *taskInput;
}

- (id) initWithWriteTaskInput: (WriteTaskInput *)taskInput;

- (void) writeTaskCompleted: (id) result;

@end // @interface WriteTaskCallback


@interface FreshDirViewWindowCreator : NSObject {
  WindowManager  *windowManager;
}

- (id) initWithWindowManager: (WindowManager *)windowManager;

- (void) createWindowForTree: (TreeContext *)treeContext;

- (DirectoryViewControl *) 
     createDirectoryViewControlForTree: (TreeContext *)treeContext;

@end // @interface FreshDirViewWindowCreator


@interface DerivedDirViewWindowCreator : FreshDirViewWindowCreator {
  ItemPathModel  *targetPath;
  DirectoryViewControlSettings  *settings;
}

- (id) initWithWindowManager:(WindowManager*)windowManager
         targetPath: (ItemPathModel *)targetPath
         settings: (DirectoryViewControlSettings *)settings;

@end // @interface DerivedDirViewWindowCreator


@interface MainMenuControl (PrivateMethods)

- (void) scanFolderUsingFilter: (BOOL) useFilter;
- (void) duplicateCurrentWindowSharingPath: (BOOL) sharePathModel;

- (NSObject <FileItemTest> *) getFilter: (NSObject <FileItemTest> *)initialTest;

/* Creates window title based on scan location, scan time and filter (if any).
 */
+ (NSString*) windowTitleForDirectoryView: (DirectoryViewControl *)control;

@end // @interface MainMenuControl (PrivateMethods)


@implementation MainMenuControl

+ (void) initialize {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // Load application-defaults from the information properties file.
  NSBundle  *bundle = [NSBundle mainBundle];
      
  NSDictionary  *appDefaults = 
    [bundle objectForInfoDictionaryKey: @"GPApplicationDefaults"];

  [defaults registerDefaults: appDefaults];
  
  // Load the ranked list of uniform types and observe the inventory to ensure 
  // that it will be extended when new types are encountered (as a result of
  // scanning).
  UniformTypeRanking  *uniformTypeRanking = 
    [UniformTypeRanking defaultUniformTypeRanking];
  UniformTypeInventory  *uniformTypeInventory = 
    [UniformTypeInventory defaultUniformTypeInventory];
    
  [uniformTypeRanking loadRanking: uniformTypeInventory];

  // Observe the inventory for newly added types. Note: we do not want to
  // receive notifications about types that have been added to the
  // inventory as a result of the recent invocation of -loadRanking:. Calling 
  // -observerUniformTypeInventory: using -performSelectorOnMainThread:...
  // ensures that any pending notifications are fired before uniformTypeRanking
  // is added as an observer. 
  [uniformTypeRanking 
     performSelectorOnMainThread: @selector(observeUniformTypeInventory:)
     withObject: uniformTypeInventory waitUntilDone: NO];
}


- (id) init {
  if (self = [super init]) {
    windowManager = [[WindowManager alloc] init];  

    ProgressPanelControl  *scanProgressPanelControl = 
      [[[ScanProgressPanelControl alloc] 
           initWithTaskExecutor: [[[ScanTaskExecutor alloc] init] autorelease] 
       ] autorelease];

    scanTaskManager =
      [[VisibleAsynchronousTaskManager alloc] 
          initWithProgressPanel: scanProgressPanelControl];    

    ProgressPanelControl  *filterProgressPanelControl = 
      [[[FilterProgressPanelControl alloc] 
           initWithTaskExecutor: [[[FilterTaskExecutor alloc] init] autorelease]
       ] autorelease];

    filterTaskManager =
      [[VisibleAsynchronousTaskManager alloc] 
          initWithProgressPanel: filterProgressPanelControl];
          
    ProgressPanelControl  *writeProgressPanelControl = 
      [[[WriteProgressPanelControl alloc] 
           initWithTaskExecutor: [[[WriteTaskExecutor alloc] init] autorelease]
       ] autorelease];

    writeTaskManager =
      [[VisibleAsynchronousTaskManager alloc] 
          initWithProgressPanel: writeProgressPanelControl];
          
    ProgressPanelControl  *readProgressPanelControl = 
      [[[ReadProgressPanelControl alloc] 
           initWithTaskExecutor: [[[ReadTaskExecutor alloc] init] autorelease]
       ] autorelease];

    readTaskManager =
      [[VisibleAsynchronousTaskManager alloc] 
          initWithProgressPanel: readProgressPanelControl];
  }
  return self;
}

- (void) dealloc {
  [windowManager release];
  
  [scanTaskManager dispose];
  [scanTaskManager release];

  [filterTaskManager dispose];
  [filterTaskManager release];
  
  [writeTaskManager dispose];
  [writeTaskManager release];

  [readTaskManager dispose];
  [readTaskManager release];
  
  [preferencesPanelControl release];
  
  [super dealloc];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
  [self scanDirectoryView: self];
}

- (void) applicationWillTerminate:(NSNotification *)notification {
  [[FileItemTestRepository defaultFileItemTestRepository]
       storeUserCreatedTests];
       
  [[UniformTypeRanking defaultUniformTypeRanking] storeRanking];
       
  [self release];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item {
  SEL  action = [item action];

  if ( action == @selector(toggleToolbarShown:) ) {
    NSWindow  *window = [[NSApplication sharedApplication] mainWindow];

    if (window == nil) {
      return NO;
    }
    [item setTitle:
       [[window toolbar] isVisible]
       ? NSLocalizedStringFromTable(@"Hide Toolbar", @"Toolbar", @"Menu item")
       : NSLocalizedStringFromTable(@"Show Toolbar", @"Toolbar", @"Menu item")];

    return YES;
  }

  if ( action == @selector(duplicateDirectoryView:) ||
       action == @selector(twinDirectoryView:)  ||

       action == @selector(customizeToolbar:) || 
       
       action == @selector(saveScanData:) ||
       action == @selector(saveDirectoryViewImage:) ||
       action == @selector(rescanDirectoryView:) ||
       action == @selector(filterDirectoryView:) ) {
    return ([[NSApplication sharedApplication] mainWindow] != nil);
  }
  
  return YES;
}


- (IBAction) scanDirectoryView: (id) sender {
  [self scanFolderUsingFilter: NO];
}

- (IBAction) scanFilteredDirectoryView: (id) sender {
  [self scanFolderUsingFilter: YES];
}


- (IBAction) rescanDirectoryView:(id)sender {
  DirectoryViewControl  *oldControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  ItemPathModel  *pathModel = [[oldControl pathModelView] pathModel];

  if (pathModel == nil) {
    return;
  }
  
  DerivedDirViewWindowCreator  *windowCreator =
    [[[DerivedDirViewWindowCreator alloc] 
         initWithWindowManager: windowManager
           targetPath: pathModel
           settings: [oldControl directoryViewControlSettings]]
         autorelease];

  TreeContext  *oldContext = [oldControl treeContext];
  ScanTaskInput  *input = 
    [[[ScanTaskInput alloc] 
         initWithPath: [[oldContext scanTree] path]
           fileSizeMeasure: [oldContext fileSizeMeasure]
           filterTest: [oldContext fileItemFilter]]
         autorelease];
    
  [scanTaskManager asynchronouslyRunTaskWithInput: input
                     callback: windowCreator
                     selector: @selector(createWindowForTree:)];
}


- (IBAction) filterDirectoryView:(id)sender {
  DirectoryViewControl  *oldControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  NSObject <FileItemTest>  *filterTest =
    [self getFilter: [oldControl fileItemMask]];
    
  if (filterTest == nil) {
    return;
  }
      
  ItemPathModel  *oldPathModel = [[oldControl pathModelView] pathModel];
  DirectoryViewControlSettings  *oldSettings = 
    [oldControl directoryViewControlSettings];

  DerivedDirViewWindowCreator  *windowCreator =
    [[[DerivedDirViewWindowCreator alloc] 
         initWithWindowManager: windowManager
           targetPath: oldPathModel
           settings: oldSettings]
         autorelease];

  FilterTaskInput  *input = 
    [[[FilterTaskInput alloc] 
         initWithTreeContext: [oldControl treeContext]
           filterTest: filterTest
           packagesAsFiles: ! [oldSettings showPackageContents]]
         autorelease];

  [filterTaskManager asynchronouslyRunTaskWithInput: input
                       callback: windowCreator
                       selector: @selector(createWindowForTree:)];
}


- (IBAction) duplicateDirectoryView:(id)sender {
  [self duplicateCurrentWindowSharingPath:NO];
}

- (IBAction) twinDirectoryView:(id)sender {
  [self duplicateCurrentWindowSharingPath:YES];
}


- (IBAction) saveScanData: (id) sender {
  DirectoryViewControl  *dirViewControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];
    
  NSSavePanel  *savePanel = [NSSavePanel savePanel];  
  [savePanel setRequiredFileType: @"xml"];
  [savePanel setTitle: 
     NSLocalizedString( @"Save scan data", @"Title of save panel") ];
  
  if ([savePanel runModal] == NSOKButton) {
    NSString  *filename = [savePanel filename];
    
    WriteTaskInput  *input = 
      [[[WriteTaskInput alloc] 
           initWithTreeContext: [dirViewControl treeContext] path: filename]  
           autorelease];
           
    WriteTaskCallback  *callback = 
      [[[WriteTaskCallback alloc] initWithWriteTaskInput: input] autorelease];
    
    [writeTaskManager asynchronouslyRunTaskWithInput: input
                        callback: callback
                        selector: @selector(writeTaskCompleted:)];
  }
}


- (IBAction) loadScanData: (id) sender {
  DirectoryViewControl  *dirViewControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];
    
  NSOpenPanel  *openPanel = [NSOpenPanel openPanel];  
  [openPanel setRequiredFileType: @"xml"];
  [openPanel setTitle: 
     NSLocalizedString( @"Load scan data", @"Title of load panel") ];
  
  if ([openPanel runModal] == NSOKButton) {
    NSString  *filename = [openPanel filename];
    
    ReadTaskInput  *input = 
      [[[ReadTaskInput alloc] initWithPath: filename] autorelease];
           
    ReadTaskCallback  *callback = 
      [[[ReadTaskCallback alloc] 
           initWithWindowManager: windowManager readTaskInput: input] 
           autorelease];
    
    [readTaskManager asynchronouslyRunTaskWithInput: input
                        callback: callback
                        selector: @selector(readTaskCompleted:)];
  }
}


- (IBAction) saveDirectoryViewImage:(id)sender {
  DirectoryViewControl  *dirViewControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  // Dialog auto-disposes when its job is done.
  SaveImageDialogControl  *saveImageDialogControl = 
    [[SaveImageDialogControl alloc] 
        initWithDirectoryViewControl: dirViewControl];
}

- (IBAction) editPreferences:(id)sender {
  if (preferencesPanelControl == nil) {
    // Lazily create the panel
    preferencesPanelControl = [[PreferencesPanelControl alloc] init];
  }

  [[preferencesPanelControl window] makeKeyAndOrderFront: self];
}


- (IBAction) toggleToolbarShown: (id) sender {
  [[[NSApplication sharedApplication] mainWindow] toggleToolbarShown: sender];
}

- (IBAction) customizeToolbar: (id) sender {
  [[[NSApplication sharedApplication] mainWindow] 
       runToolbarCustomizationPalette: sender];
}


- (IBAction) openWebsite: (id) sender {
  NSBundle  *bundle = [NSBundle mainBundle];

  NSURL  *url = [NSURL URLWithString: 
                   [bundle objectForInfoDictionaryKey: @"GPWebsiteURL"]];

  [[NSWorkspace sharedWorkspace] openURL: url];
}

@end // @implementation MainMenuControl


@implementation MainMenuControl (PrivateMethods)

- (void) scanFolderUsingFilter: (BOOL) useFilter {
  NSOpenPanel  *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles: NO];
  [openPanel setCanChooseDirectories: YES];
  [openPanel setAllowsMultipleSelection: NO];
  
  [openPanel setTitle: NSLocalizedString(@"Scan folder", 
                                         @"Title of open panel") ];
  [openPanel setPrompt: NSLocalizedString(@"Scan", @"Prompt in open panel") ];

  if ([openPanel runModalForTypes:nil] != NSOKButton) {
    return; // Abort
  }  

  NSString  *pathToScan = [[openPanel filenames] objectAtIndex: 0];
  
  NSObject <FileItemTest>  *filter = useFilter ? [self getFilter: nil] : nil;

  NSString  *fileSizeMeasure =
    [[NSUserDefaults standardUserDefaults] stringForKey: FileSizeMeasureKey];

  FreshDirViewWindowCreator  *windowCreator =
    [[[FreshDirViewWindowCreator alloc] initWithWindowManager: windowManager]
         autorelease];
  ScanTaskInput  *input = 
    [[[ScanTaskInput alloc] initWithPath: pathToScan
                              fileSizeMeasure: fileSizeMeasure 
                              filterTest: filter] 
         autorelease];
    
  [scanTaskManager asynchronouslyRunTaskWithInput: input
                     callback: windowCreator
                     selector: @selector(createWindowForTree:)];
}


- (void) duplicateCurrentWindowSharingPath: (BOOL) sharePathModel {
  DirectoryViewControl  *oldControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  // Share or clone the path model.
  ItemPathModel  *pathModel = [[oldControl pathModelView] pathModel];

  if (!sharePathModel) {
    pathModel = [[pathModel copy] autorelease];
  }

  DirectoryViewControl  *newControl = 
    [[DirectoryViewControl alloc] 
        initWithTreeContext: [oldControl treeContext]
          pathModel: pathModel
          settings: [oldControl directoryViewControlSettings]];
  // Note: The control should auto-release itself when its window closes
    
  // Force loading (and showing) of the window.
  [windowManager addWindow:[newControl window] 
                   usingTitle:[[oldControl window] title]];
}


- (NSObject <FileItemTest> *)getFilter: (NSObject <FileItemTest> *)initialTest {
  EditFilterWindowControl  *editFilterWindowControl = 
    [[[EditFilterWindowControl alloc] init] autorelease];

  [[editFilterWindowControl window] setTitle: 
      NSLocalizedString( @"Apply filter", @"Window title" ) ];
  [editFilterWindowControl removeApplyButton];
  [editFilterWindowControl representFileItemTest: initialTest];

  ModalityTerminator  *stopModal = 
    [[[ModalityTerminator alloc] init] autorelease];
    
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver: stopModal selector: @selector(abortModalAction:)
        name: CancelPerformedEvent object: editFilterWindowControl];
  [nc addObserver: stopModal selector: @selector(abortModalAction:)
        name: ClosePerformedEvent object: editFilterWindowControl];
        // Closing a window can be considered the same as cancelling.
  [nc addObserver: stopModal selector: @selector(stopModalAction:)
        name: OkPerformedEvent object: editFilterWindowControl];

  int  status = [NSApp runModalForWindow: [editFilterWindowControl window]];

  [nc removeObserver: stopModal];
  
  [[editFilterWindowControl window] close];

  if (status ==  NSRunAbortedResponse) {
    return nil; // Aborted
  }
  NSAssert(status == NSRunStoppedResponse, @"Unexpected status.");
  
  // Get rule from window
  return [editFilterWindowControl createFileItemTest];
}


+ (NSString*) windowTitleForDirectoryView: (DirectoryViewControl *)control {
  TreeContext  *treeContext = [control treeContext];
  NSString  *scanPath = [[treeContext scanTree] path];

  NSString  *scanTimeString = [treeContext stringForScanTime]; 
  NSObject <FileItemTest>  *filter = [treeContext fileItemFilter];

  if (filter == nil) {
    return [NSString stringWithFormat: @"%@ - %@", 
                                         scanPath, scanTimeString];
  }
  else {
    return [NSString stringWithFormat: @"%@ - %@ - %@", 
                                         scanPath, scanTimeString,
                                         [filter name] ];
  }
}

@end // @implementation MainMenuControl (PrivateMethods)


@implementation ModalityTerminator

- (void) abortModalAction: (NSNotification *)notification {
  [NSApp abortModal];
}

- (void) stopModalAction: (NSNotification *)notification {
  [NSApp stopModal];
}

@end // @implementation ModalityTerminator


@implementation ReadTaskCallback

// Overrides designated initialiser
- (id) init {
  NSAssert(NO, @"Use initWithReadTaskInput: instead.");
}

- (id) initWithWindowManager: (WindowManager *)windowManagerVal 
         readTaskInput: (ReadTaskInput *)taskInputVal {
  if (self = [super init]) {
    windowManager = [windowManagerVal retain];
    taskInput = [taskInputVal retain];
  }
  
  return self;
}

- (void) dealloc {
  [windowManager release];
  [taskInput release];

  [super dealloc];
}


- (void) readTaskCompleted: (id) result {
  if ( result == nil ) {
    // The task was aborted. Silently ignore.
  }
  else if ([result isKindOfClass: [TreeContext class]]) {
    FreshDirViewWindowCreator  *windowCreator =
      [[[FreshDirViewWindowCreator alloc] 
           initWithWindowManager: windowManager] autorelease];
      
    [windowCreator createWindowForTree: result];
  }
  else if ([result isKindOfClass: [NSError class]]) {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];

    NSString  *format = 
      NSLocalizedString( @"Failed to load the scan data from \"%@\"", 
                         @"Alert message (with filename arg)" );

    [alert addButtonWithTitle: OK_BUTTON_TITLE];
    [alert setMessageText: 
             [NSString stringWithFormat: format, 
                                         [[taskInput path] lastPathComponent]]];
    [alert setInformativeText: [result localizedDescription]];

    [alert runModal];
  }
  else {
    NSAssert(NO, @"Unexpected result type.");
  }
}

@end // @interface ReadTaskCallback


@implementation WriteTaskCallback

// Overrides designated initialiser
- (id) init {
  NSAssert(NO, @"Use initWithWriteTaskInput: instead.");
}

- (id) initWithWriteTaskInput: (WriteTaskInput *)taskInputVal {
  if (self = [super init]) {
    taskInput = [taskInputVal retain];
  }
  
  return self;
}

- (void) dealloc {
  [taskInput release];

  [super dealloc];
}


- (void) writeTaskCompleted: (id) result {
  NSAlert  *alert = [[[NSAlert alloc] init] autorelease];
  NSString  *msgFormat = nil;

  if (result == SuccessfulVoidResult) {
    [alert setAlertStyle:  NSInformationalAlertStyle];
    
    msgFormat = 
      NSLocalizedString( @"Successfully saved the scan data to \"%@\"", 
                         @"Alert message (with filename arg)" );
  }
  else if (result == nil) {
    // Writing was aborted
    msgFormat = NSLocalizedString( @"Aborted saving the scan data to \"%@\"", 
                                   @"Alert message (with filename arg)" );
    [alert setInformativeText: 
       NSLocalizedString( @"The resulting file is valid but incomplete.", 
                          @"Alert informative text" )];
  }
  else {
    // An error occured while writing
    msgFormat = NSLocalizedString( @"Failed to save the scan data to \"%@\"", 
                                   @"Alert message (with filename arg)" );
    [alert setInformativeText: [((NSError *)result) localizedDescription]];     
  }

  [alert setMessageText: 
           [NSString stringWithFormat: msgFormat, 
                                       [[taskInput path] lastPathComponent]]];
  
  [alert addButtonWithTitle: OK_BUTTON_TITLE];
  [alert runModal];
}

@end // @interface WriteTaskCallback


@implementation FreshDirViewWindowCreator

// Overrides designated initialiser.
- (id) init {
  NSAssert(NO, @"Use initWithWindowManager: instead.");
}

- (id) initWithWindowManager:(WindowManager*)windowManagerVal {
  if (self = [super init]) {
    windowManager = [windowManagerVal retain];
  }
  return self;
}

- (void) dealloc {
  [windowManager release];
  
  [super dealloc];
}


- (void) createWindowForTree: (TreeContext *)treeContext {
  if (treeContext == nil) {
    // Reading failed or cancelled. Don't create a window.
    return;
  }
  
  // If there is a filter, ensure it has a name
  NSObject <FileItemTest>  *filter = [treeContext fileItemFilter];    
  if (filter != nil && [filter name] == nil) {
    NSString  *format = NSLocalizedString( @"Filter%d", 
                                           @"Filter naming template." );
    
    [filter setName: [NSString stringWithFormat: format, nextFilterId++]];
  }

  // Note: The control should auto-release itself when its window closes  
  DirectoryViewControl  *dirViewControl = 
    [[self createDirectoryViewControlForTree: treeContext] retain];
  
  NSString  *title = 
    [MainMenuControl windowTitleForDirectoryView: dirViewControl];
  
  // Force loading (and showing) of the window.
  [windowManager addWindow: [dirViewControl window] usingTitle: title];
}

- (DirectoryViewControl*) 
     createDirectoryViewControlForTree: (TreeContext *)treeContext {
  return [[[DirectoryViewControl alloc] 
              initWithTreeContext: treeContext] autorelease];
}

@end // @implementation FreshDirViewWindowCreator


@implementation DerivedDirViewWindowCreator

// Overrides designated initialiser.
- (id) initWithWindowManager:(WindowManager*)windowManagerVal {
  NSAssert(NO, 
    @"Use initWithWindowManager:targetPath:settings instead.");
}

- (id) initWithWindowManager: (WindowManager *)windowManagerVal
         targetPath: (ItemPathModel *)targetPathVal
         settings: (DirectoryViewControlSettings *)settingsVal {
         
  if (self = [super initWithWindowManager: windowManagerVal]) {
    targetPath = [targetPathVal retain];
    // Note: The state of "targetPath" may change during scanning/filtering 
    // (which happens in the background). This is okay and even desired. When 
    // the callback occurs the path in the new window will match the current
    // path in the original window.
     
    settings = [settingsVal retain];
  }
  return self;
}

- (void) dealloc {
  [targetPath release];
  [settings release];
  
  [super dealloc];
}


- (DirectoryViewControl*) 
     createDirectoryViewControlForTree: (TreeContext *)treeContext {
       
  // Try to match the path.
  ItemPathModel  *path = 
    [[[ItemPathModel alloc] initWithTreeContext: treeContext] autorelease];

  [path suppressVisibleTreeChangedNotifications: YES];

  NSEnumerator  *fileItemEnum = [[targetPath fileItemPath] objectEnumerator];
  FileItem  *targetItem;
  FileItem  *itemToSelect = nil;

  BOOL  insideScanTree = NO;
  BOOL  insideVisibleTree = NO;
  BOOL  hasVisibleItems = NO;
  
  while (targetItem = [fileItemEnum nextObject]) {
    if ( insideScanTree ) {
      // Only try to extend the visible path once we are inside the scan tree,
      // as "path" starts at its scan tree.
      if ( [path extendVisiblePathToSimilarFileItem: targetItem] ) {
        if (! insideVisibleTree) {
          [path moveVisibleTreeDown];
        }
        else {
          hasVisibleItems = YES;
        }
      }
      else {
        // Failure to match, so should stop matching remainder of path.
        break;
      }
    }
    if (itemToSelect == nil && targetItem == [targetPath selectedFileItem]) {
      // Found the selected item. It is the path's current end point. 
      itemToSelect = [path lastFileItem];
    }
    if (!insideVisibleTree && targetItem == [targetPath visibleTree]) {
      // The remainder of this path can remain visible.
      insideVisibleTree = YES;
    }
    if (!insideScanTree && targetItem == [targetPath scanTree]) {
      // We can now start extending "path" to match "targetPath". 
      insideScanTree = YES;
    }
  }

  if (hasVisibleItems) {
    [path setVisiblePathLocking: YES];
  }
  
  if (itemToSelect != nil) {
    // Match the selection to that of the original path. 
    [path selectFileItem: itemToSelect];
  }
  else {
    // Did not manage to match the new path all the way up to the selected
    // item in the original path. The selected item of the new path can 
    // therefore be set to the path endpoint (as that is the closest it can 
    // come to matching the old selection).
    [path selectFileItem: [path lastFileItem]];
  }
        
  [path suppressVisibleTreeChangedNotifications: NO];

  return [[[DirectoryViewControl alloc] 
             initWithTreeContext: treeContext pathModel: path 
               settings: settings] autorelease];
}

@end // @implementation DerivedDirViewWindowCreator
