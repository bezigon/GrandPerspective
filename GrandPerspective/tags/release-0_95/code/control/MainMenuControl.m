#import "MainMenuControl.h"

#import "DirectoryItem.h"

#import "DirectoryViewControl.h"
#import "SaveImageDialogControl.h"
#import "EditFilterWindowControl.h"
#import "ItemPathModel.h"

#import "WindowManager.h"

#import "AsynchronousTaskManager.h"
#import "ScanTaskExecutor.h"


@interface PostScanningWindowCreator : NSObject {
  WindowManager  *windowManager;
}

- (id) initWithWindowManager:(WindowManager*)windowManager;

- (void) createWindowForTree:(DirectoryItem*)itemTree;
- (DirectoryViewControl*) 
     createDirectoryViewControlForTree:(DirectoryItem*)tree;

@end


@interface PostScanningCustomWindowCreator : PostScanningWindowCreator {
  NSArray  *invisibleFileItemTargetPath; 
  NSArray  *visibleFileItemTargetPath;
  NSString  *fileItemHashingKey;
  NSObject <FileItemTest>  *fileItemMask;
  BOOL  fileItemMaskEnabled;
  
  // HACK. Should not really be needed
  DirectoryViewControl  *dirViewControl;
}

- (id) initWithWindowManager:(WindowManager*)windowManager
         targetPath:(ItemPathModel*)targetPath
         fileItemHashingKey:(NSString*)key;

- (void) setFileItemMask:(NSObject <FileItemTest> *) mask;
- (void) enableFileItemMask:(BOOL) flag;

@end


@interface MainMenuControl (PrivateMethods)

- (void) editFilterWindowCancelAction:(NSNotification*)notification;
- (void) editFilterWindowOkAction:(NSNotification*)notification;

- (void) duplicateCurrentWindowSharingPath:(BOOL)sharePathModel;

@end


@implementation MainMenuControl

- (id) init {
  if (self = [super init]) {
    windowManager = [[WindowManager alloc] init];  

    scanTaskManager = 
      [[AsynchronousTaskManager alloc] initWithTaskExecutor:
         [[[ScanTaskExecutor alloc] init] autorelease]];
  }
  return self;
}

- (void) dealloc {
  [windowManager release];
  
  [scanTaskManager dispose];
  [scanTaskManager release];
  
  [editFilterWindowControl release];

  [super dealloc];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
  [self openDirectoryView:self];
}


- (BOOL) validateMenuItem:(NSMenuItem *)anItem {
  if ( [anItem action]==@selector(duplicateDirectoryView:) ||
       [anItem action]==@selector(twinDirectoryView:) ) {
    return ([[NSApplication sharedApplication] mainWindow] != nil);
  }
  
  if ( [anItem action]==@selector(saveDirectoryViewImage:) ||
       [anItem action]==@selector(rescanDirectoryView:) ||
       [anItem action]==@selector(filterDirectoryView:) ) {
    return ([[NSApplication sharedApplication] mainWindow] != nil);
  }
  
  return YES;
}


- (IBAction) openDirectoryView:(id)sender {
  NSOpenPanel  *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:NO];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setAllowsMultipleSelection:NO];

  if ([openPanel runModalForTypes:nil] == NSOKButton) {
    NSString  *dirName = [[openPanel filenames] objectAtIndex:0];
    
    PostScanningWindowCreator  *windowCreator =
      [[PostScanningWindowCreator alloc] initWithWindowManager:windowManager];
      
    [scanTaskManager asynchronouslyRunTaskWithInput:dirName 
                       callBack:windowCreator
                       selector:@selector(createWindowForTree:)];
                       
    [windowCreator release];
  }
}


- (IBAction) rescanDirectoryView:(id)sender {
  NSLog(@"rescan");
  DirectoryViewControl  *oldControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  ItemPathModel  *itemPathModel = [oldControl itemPathModel];

  if (itemPathModel != nil) {
    NSString  *dirName = [itemPathModel rootFilePathName];
    NSObject <FileItemTest>  *fileItemMask = nil;
    
    PostScanningCustomWindowCreator  *windowCreator =
      [[PostScanningCustomWindowCreator alloc] 
          initWithWindowManager:windowManager
            targetPath:itemPathModel 
            fileItemHashingKey:[oldControl fileItemHashingKey]];

    [windowCreator setFileItemMask:[oldControl fileItemMask]];
    [windowCreator enableFileItemMask:[oldControl fileItemMaskEnabled]];
    
    [scanTaskManager asynchronouslyRunTaskWithInput:dirName 
                       callBack:windowCreator
                       selector:@selector(createWindowForTree:)];
                       
    [windowCreator release];
  }
}


- (IBAction) duplicateDirectoryView:(id)sender {
  [self duplicateCurrentWindowSharingPath:NO];
}

- (IBAction) twinDirectoryView:(id)sender {
  [self duplicateCurrentWindowSharingPath:YES];
}


- (IBAction) saveDirectoryViewImage:(id)sender {
  DirectoryViewControl  *dirViewControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];

  // Dialog auto-disposes when its job is done.
  SaveImageDialogControl  *saveImageDialogControl = 
    [[SaveImageDialogControl alloc] 
        initWithDirectoryViewControl: dirViewControl];
}

@end // @implementation MainMenuControl


@implementation MainMenuControl (PrivateMethods)

- (void) editFilterWindowCancelAction:(NSNotification*)notification {
  [NSApp abortModal];
}

- (void) editFilterWindowOkAction:(NSNotification*)notification {
  [NSApp stopModal];
}


- (void) duplicateCurrentWindowSharingPath:(BOOL)sharePathModel {
  DirectoryViewControl  *oldControl = 
    [[[NSApplication sharedApplication] mainWindow] windowController];
  DirectoryItem  *itemTree = [oldControl itemTree];
  
  if (itemTree!=nil) {
    NSString  *fileItemHashingKey = [oldControl fileItemHashingKey];

    // Share or clone the path model.
    ItemPathModel  *itemPathModel = nil;

    itemPathModel = [oldControl itemPathModel];
    if (!sharePathModel) {
      itemPathModel = [[itemPathModel copy] autorelease];
    }
        
    DirectoryViewControl  *newControl = 
      [[DirectoryViewControl alloc] 
          initWithItemTree:itemTree 
          itemPathModel:itemPathModel
          fileItemHashingKey:fileItemHashingKey];          
    // Note: The control should auto-release itself when its window closes
    
    // Force loading (and showing) of the window.
    [windowManager addWindow:[newControl window] 
                     usingTitle:[[oldControl window] title]];
    
    [newControl setFileItemMask: [oldControl fileItemMask]];
    [newControl enableFileItemMask: [oldControl fileItemMaskEnabled]];
  }
}

@end // @implementation MainMenuControl (PrivateMethods)


@implementation PostScanningWindowCreator

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


- (void) createWindowForTree:(DirectoryItem*)itemTree {
  if (itemTree == nil) {
    // Reading failed or cancelled. Don't create a window.
    return;
  }

  // Note: The control should auto-release itself when its window closes  
  DirectoryViewControl  *dirViewControl = 
    [[self createDirectoryViewControlForTree:itemTree] retain];
  
  // Create window title based on scan location and time.
  NSString*  title = 
    [NSString stringWithFormat:@"%@ - %@", [itemTree name],
                [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S"
                                 timeZone:nil locale:nil]];

  // Force loading (and showing) of the window.
  [windowManager addWindow:[dirViewControl window] usingTitle:title];
}

- (DirectoryViewControl*) 
     createDirectoryViewControlForTree:(DirectoryItem*)tree {
  return [[[DirectoryViewControl alloc] initWithItemTree:tree] autorelease];
}

@end // @implementation PostScanningWindowCreator


@implementation PostScanningCustomWindowCreator

// Overrides designated initialiser.
- (id) initWithWindowManager:(WindowManager*)windowManagerVal {
  NSAssert(NO, 
    @"Use initWithWindowManager:targetPath:fileItemHashingKey instead.");
}

- (id) initWithWindowManager:(WindowManager*)windowManagerVal
         targetPath:(ItemPathModel*)targetPath
         fileItemHashingKey:(NSString*)key; {
  if (self = [super initWithWindowManager:windowManagerVal]) {
    invisibleFileItemTargetPath = [[targetPath invisibleFileItemPath] retain];
    visibleFileItemTargetPath = [[targetPath visibleFileItemPath] retain];

    fileItemHashingKey = [key retain];
    
    fileItemMask = nil;
    fileItemMaskEnabled = NO;
  }
  return self;
}

- (void) dealloc {
  [invisibleFileItemTargetPath release];
  [visibleFileItemTargetPath release];
  [fileItemHashingKey release];
  [fileItemMask release];
  
  NSAssert(dirViewControl == nil, @"dirViewControl not nil.");
  
  [super dealloc];
}

- (void) setFileItemMask:(NSObject <FileItemTest> *) mask {
  if (mask != fileItemMask) {
    [fileItemMask release];
    fileItemMask = [mask retain];
  }
}

- (void) enableFileItemMask:(BOOL) flag {
  fileItemMaskEnabled = flag;
}


- (void) createWindowForTree:(DirectoryItem*)itemTree {
  [super createWindowForTree:itemTree];
  
  // Now the window is shown, apply the mask (if any)
  [dirViewControl setFileItemMask: fileItemMask];
  [dirViewControl enableFileItemMask: fileItemMaskEnabled];
  [dirViewControl release];
  dirViewControl = nil;
}

- (DirectoryViewControl*) 
     createDirectoryViewControlForTree:(DirectoryItem*)tree {
  // Try to match the path.
  ItemPathModel  *path = 
    [[[ItemPathModel alloc] initWithTree:tree] autorelease];

  [path suppressItemPathChangedNotifications:YES];
    
  BOOL  ok = YES;
  NSEnumerator  *fileItemEnum = [invisibleFileItemTargetPath objectEnumerator];
  FileItem  *fileItem;
    
  [fileItemEnum nextObject]; // Skip the root.
  while (ok && (fileItem = [fileItemEnum nextObject])) {
    ok = [path extendVisibleItemPathToFileItemWithName:[fileItem name]];
  }
  // Make this extension "invisible".
  while ([path canMoveTreeViewDown]) {
    [path moveTreeViewDown];
  }
    
  if (ok && visibleFileItemTargetPath != nil) {
    BOOL  hasVisibleItems = NO;
      
    fileItemEnum = [visibleFileItemTargetPath objectEnumerator];
    while (ok && (fileItem = [fileItemEnum nextObject])) {
      ok = [path extendVisibleItemPathToFileItemWithName:[fileItem name]];
      if (ok) {
        hasVisibleItems = YES;
      }
    }
      
    if (hasVisibleItems) {
      [path setVisibleItemPathLocking:YES];
    }
  }
        
  [path suppressItemPathChangedNotifications:NO];

  dirViewControl = [[DirectoryViewControl alloc] 
                       initWithItemTree:tree itemPathModel:path
                       fileItemHashingKey:fileItemHashingKey];
  
  return dirViewControl;
}

@end // @implementation PostScanningCustomWindowCreator
