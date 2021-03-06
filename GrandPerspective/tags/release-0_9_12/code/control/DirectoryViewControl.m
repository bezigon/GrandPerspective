#import "DirectoryViewControl.h"

#import "PlainFileItem.h"
#import "DirectoryItem.h"
#import "DirectoryView.h"
#import "ItemPathModel.h"
#import "ItemPathModelView.h"
#import "FileItemMappingScheme.h"
#import "FileItemMappingCollection.h"
#import "ColorListCollection.h"
#import "DirectoryViewControlSettings.h"
#import "FileItemTest.h"
#import "TreeContext.h"
#import "EditFilterWindowControl.h"
#import "ColorLegendTableViewControl.h"
#import "PreferencesPanelControl.h"
#import "ItemTreeDrawerSettings.h"
#import "ControlConstants.h"
#import "UniformType.h"

#import "UniqueTagsTransformer.h"


NSString  *DeleteNothing = @"delete nothing";
NSString  *OnlyDeleteFiles = @"only delete files";
NSString  *DeleteFilesAndFolders = @"delete files and folders";


@interface DirectoryViewControl (PrivateMethods)

- (BOOL) canRevealSelectedFile;

- (BOOL) canDeleteSelectedFile;
- (void) confirmDeleteSelectedFileAlertDidEnd: (NSAlert *)alert 
           returnCode: (int) returnCode contextInfo: (void *)contextInfo;
- (void) deleteSelectedFile;
- (void) fileItemDeleted: (NSNotification *)notification;

- (void) createEditMaskFilterWindow;

- (void) updateButtonState:(NSNotification*)notification;
- (void) visibleTreeChanged:(NSNotification*)notification;
- (void) maskChanged;
- (void) updateMask;

- (void) updateFileDeletionSupport;

- (void) maskWindowApplyAction:(NSNotification*)notification;
- (void) maskWindowCancelAction:(NSNotification*)notification;
- (void) maskWindowOkAction:(NSNotification*)notification;
- (void) maskWindowDidBecomeKey:(NSNotification*)notification;

@end


/* Manages a group of related controls in the Focus panel.
 */
@interface ItemInFocusControls : NSObject {
  NSTextView  *pathTextView;
  NSTextField  *titleField;
  NSTextField  *exactSizeField;
  NSTextField  *sizeField;
}

- (id) initWithPathTextView: (NSTextView *)textView 
         titleField: (NSTextField *)titleField
         exactSizeField: (NSTextField *)exactSizeField
         sizeField: (NSTextField *)sizeField;


/* Clears the controls.
 */
- (void) clear;

/* Show the details of the given item.
 */
- (void) showFileItem: (FileItem *)item;

/* Show the details of the given item. The provided "pathString" and 
 * "sizeString" provided will be used (if -showFileItem: is invoked instead, 
 * these will be constructed before invoking this method). Invoking this method
 * directly is useful in cases where these have been constructed already (to 
 * avoid having to do so twice).
 */
- (void) showFileItem: (FileItem *)item itemPath: (NSString *)pathString
           sizeString: (NSString *)sizeString;

/* Abstract method. Override to return title for the given item.
 */
- (NSString *) titleForFileItem: (FileItem *)item;

@end


/* Manages the "Item in view" controls in the Focus panel.
 */
@interface  FolderInViewFocusControls : ItemInFocusControls {
}
@end


/* Manages the "Selected item" controls in the Focus panel.
 */
@interface  SelectedItemFocusControls : ItemInFocusControls {
}
@end


@implementation DirectoryViewControl

- (id) initWithTreeContext: (TreeContext *)treeContextVal {
  ItemPathModel  *pathModel = 
    [[[ItemPathModel alloc] initWithTreeContext: treeContextVal] autorelease];

  // Default settings
  DirectoryViewControlSettings  *defaultSettings =
    [[[DirectoryViewControlSettings alloc] init] autorelease];

  return [self initWithTreeContext: treeContextVal
                 pathModel: pathModel 
                 settings: defaultSettings];
}


// Special case: should not cover (override) super's designated initialiser in
// NSWindowController's case
- (id) initWithTreeContext: (TreeContext *)treeContextVal
         pathModel: (ItemPathModel *)pathModel
         settings: (DirectoryViewControlSettings *)settings {
  if (self = [super initWithWindowNibName:@"DirectoryViewWindow" owner:self]) {
    NSAssert([pathModel volumeTree] == [treeContextVal volumeTree], 
               @"Tree mismatch");
    treeContext = [treeContextVal retain];
    pathModelView = [[ItemPathModelView alloc] initWithPathModel: pathModel];
    initialSettings = [settings retain];

    scanPathName = [[[treeContext scanTree] path] retain];
    
    invisiblePathName = nil;
       
    colorMappings = 
      [[FileItemMappingCollection defaultFileItemMappingCollection] retain];
    colorPalettes = 
      [[ColorListCollection defaultColorListCollection] retain];
  }

  return self;
}


- (void) dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  NSUserDefaults  *userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults removeObserver: self forKeyPath: FileDeletionTargetsKey];
  [userDefaults removeObserver: self forKeyPath: ConfirmFileDeletionKey];
  
  [visibleFolderFocusControls release];
  [selectedItemFocusControls release];
  
  [treeContext release];
  [pathModelView release];
  [initialSettings release];
  
  [fileItemMask release];
  
  [colorMappings release];
  [colorPalettes release];
  [colorLegendControl release];
  
  [editMaskFilterWindowControl release];

  [scanPathName release];
  [invisiblePathName release];
  
  [super dealloc];
}


- (NSObject <FileItemTest> *) fileItemMask {
  return fileItemMask;
}

- (ItemPathModelView *) pathModelView {
  return pathModelView;
}

- (DirectoryView*) directoryView {
  return mainView;
}

- (DirectoryViewControlSettings*) directoryViewControlSettings {
  UniqueTagsTransformer  *tagMaker = 
    [UniqueTagsTransformer defaultUniqueTagsTransformer];
  NSString  *colorMappingKey = 
    [tagMaker nameForTag: [[colorMappingPopUp selectedItem] tag]];
  NSString  *colorPaletteKey = 
    [tagMaker nameForTag: [[colorPalettePopUp selectedItem] tag]];

  return 
    [[[DirectoryViewControlSettings alloc]
         initWithColorMappingKey: colorMappingKey
           colorPaletteKey: colorPaletteKey
           mask: fileItemMask
           maskEnabled: [maskCheckBox state]==NSOnState
           showEntireVolume: [showEntireVolumeCheckBox state]==NSOnState
           showPackageContents: [showPackageContentsCheckBox state]==NSOnState]
         autorelease];
}

- (TreeContext*) treeContext {
  return treeContext;
}


- (void) windowDidLoad {
  [mainView postInitWithPathModelView: pathModelView];
  
  [self updateFileDeletionSupport];

  NSUserDefaults  *userDefaults = [NSUserDefaults standardUserDefaults];
  NSBundle  *mainBundle = [NSBundle mainBundle];
  
  //----------------------------------------------------------------
  // Configure the "Display" panel
  
  UniqueTagsTransformer  *tagMaker = 
    [UniqueTagsTransformer defaultUniqueTagsTransformer];
  
  [colorMappingPopUp removeAllItems];  
  [tagMaker addLocalisedNamesToPopUp: colorMappingPopUp
              names: [colorMappings allKeys]
              select: [initialSettings colorMappingKey]
              table: @"Names"];
  [self colorMappingChanged: nil];
  
  [colorPalettePopUp removeAllItems];
  [tagMaker addLocalisedNamesToPopUp: colorPalettePopUp
              names: [colorPalettes allKeys]
              select: [initialSettings colorPaletteKey]  
              table: @"Names"];
  [self colorPaletteChanged: nil];
  
  // NSTableView apparently does not retain its data source, so keeping a
  // reference here so that it can be released.
  colorLegendControl = 
    [[ColorLegendTableViewControl alloc] initWithDirectoryView: mainView 
                                           tableView: colorLegendTable];
  
  fileItemMask = [[initialSettings fileItemMask] retain];
  [maskCheckBox setState: ( [initialSettings fileItemMaskEnabled]
                              ? NSOnState : NSOffState ) ];
  [self maskChanged];
  
  [showEntireVolumeCheckBox setState: 
     ( [initialSettings showEntireVolume] ? NSOnState : NSOffState ) ];  
  [showPackageContentsCheckBox setState: 
     ( [initialSettings showPackageContents] ? NSOnState : NSOffState ) ];
  
  [initialSettings release];
  initialSettings = nil;
  
  //---------------------------------------------------------------- 
  // Configure the "Info" panel

  FileItem  *volumeTree = [pathModelView volumeTree];
  FileItem  *scanTree = [pathModelView scanTree];
  FileItem  *visibleTree = [pathModelView visibleTree];

  NSString  *volumeName = [volumeTree name];
  NSImage  *volumeIcon = 
    [[NSWorkspace sharedWorkspace] iconForFile: volumeName];
  [volumeIconView setImage: volumeIcon];

  [volumeNameField setStringValue: 
    [[NSFileManager defaultManager] displayNameAtPath: volumeName]];

  [scanPathTextView setString: [scanTree name]];
  [scanPathTextView setDrawsBackground: NO];
  [[scanPathTextView enclosingScrollView] setDrawsBackground: NO];

  NSObject <FileItemTest>  *filter = [treeContext fileItemFilter];
  if (filter != nil) {
    [filterNameField setStringValue: [filter name]];
    [filterDescriptionTextView setString: [filter description]];
  }
  else {
    [filterNameField setStringValue: 
       NSLocalizedString( @"None", 
                          @"The filter name when there is no filter." ) ];
    [filterDescriptionTextView setString: @""];
  }

  
  [scanTimeField setStringValue: 
    [[treeContext scanTime] descriptionWithCalendarFormat:@"%H:%M:%S"
                              timeZone:nil locale:nil]];
  [fileSizeMeasureField setStringValue: 
    [mainBundle localizedStringForKey: [treeContext fileSizeMeasure] value: nil
                  table: @"Names"]];

  unsigned long long  scanTreeSize = [scanTree itemSize];
  unsigned long long  freeSpace = [treeContext freeSpace];
  unsigned long long  volumeSize = [volumeTree itemSize];
  unsigned long long  miscUsedSpace = volumeSize - freeSpace - scanTreeSize;

  [volumeSizeField setStringValue:  
                            [FileItem stringForFileItemSize: volumeSize]];  
  [treeSizeField setStringValue: 
                            [FileItem stringForFileItemSize: scanTreeSize]];
  [miscUsedSpaceField setStringValue:  
                            [FileItem stringForFileItemSize: miscUsedSpace]];
  [freeSpaceField setStringValue: 
                            [FileItem stringForFileItemSize: freeSpace]];
  [freedSpaceField setStringValue: 
                   [FileItem stringForFileItemSize: [treeContext freedSpace]]];
                   
  //---------------------------------------------------------------- 
  // Configure the "Focus" panel
  
  visibleFolderFocusControls = 
    [[FolderInViewFocusControls alloc]
        initWithPathTextView: visibleFolderPathTextView 
          titleField: visibleFolderTitleField
          exactSizeField: visibleFolderExactSizeField
          sizeField: visibleFolderSizeField];

  selectedItemFocusControls = 
    [[SelectedItemFocusControls alloc]
        initWithPathTextView: selectedItemPathTextView 
          titleField: selectedItemTitleField
          exactSizeField: selectedItemExactSizeField
          sizeField: selectedItemSizeField];


  //---------------------------------------------------------------- 
  // Miscellaneous initialisation

  [super windowDidLoad];
  
  NSAssert(invisiblePathName == nil, @"invisiblePathName unexpectedly set.");
  invisiblePathName = [[visibleTree path] retain];

  [self showEntireVolumeCheckBoxChanged: nil];
  [self showPackageContentsCheckBoxChanged: nil];

  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];

  [nc addObserver:self selector: @selector(updateButtonState:)
        name: SelectedItemChangedEvent object: pathModelView];
  [nc addObserver:self selector: @selector(visibleTreeChanged:)
        name: VisibleTreeChangedEvent object: pathModelView];
  [nc addObserver:self selector: @selector(updateButtonState:)
        name: VisiblePathLockingChangedEvent object: [pathModelView pathModel]];
        
  [userDefaults addObserver: self forKeyPath: FileDeletionTargetsKey
                  options: 0 context: nil];
  [userDefaults addObserver: self forKeyPath: ConfirmFileDeletionKey
                  options: 0 context: nil];

  [nc addObserver:self selector: @selector(fileItemDeleted:)
        name: FileItemDeletedEvent object: treeContext];

  [self visibleTreeChanged: nil];

  [[self window] makeFirstResponder:mainView];
  [[self window] makeKeyAndOrderFront:self];  
}

// Invoked because the controller is the delegate for the window.
- (void) windowDidBecomeMain:(NSNotification*)notification {
  if (editMaskFilterWindowControl != nil) {
    [[editMaskFilterWindowControl window] 
        orderWindow:NSWindowBelow relativeTo:[[self window] windowNumber]];
  }
}

// Invoked because the controller is the delegate for the window.
- (void) windowWillClose:(NSNotification*)notification {
  [self autorelease];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id) object 
           change: (NSDictionary *)change context: (void *)context {
  if (object == [NSUserDefaults standardUserDefaults]) {
    if ([keyPath isEqualToString: FileDeletionTargetsKey] ||
        [keyPath isEqualToString: ConfirmFileDeletionKey]) {
      [self updateFileDeletionSupport];
    }
  }
}

- (IBAction) upAction: (id) sender {
  [pathModelView moveVisibleTreeUp];
  
  // Automatically lock path as well.
  [[pathModelView pathModel] setVisiblePathLocking: YES];
}

- (IBAction) downAction: (id) sender {
  [pathModelView moveVisibleTreeDown];
}


- (IBAction) openFileInFinder: (id) sender {
  FileItem  *fileToOpen = [pathModelView selectedFileItem];
  DirectoryItem  *package = nil;
  
  // Work-around for bug/limitation of NSWorkSpace. It apparently cannot 
  // select files that are inside a package, unless the package is the root
  // path. So check if the selected file is inside a package. If so, use it
  // as a root path.
  DirectoryItem  *ancestor = [fileToOpen parentDirectory];
  while (ancestor != nil) {
    if ( [ancestor isPackage] ) {
      if (package != nil) {
        // The package in which the selected item resides is inside a package
        // itself. Open this inner package instead (as opening the selected
        // file will not succeed).
        fileToOpen = package;
      }
      package = ancestor;
    }
    ancestor = [ancestor parentDirectory];
  }
  
  NSString  *filePath = [fileToOpen path];
  NSString  *rootPath = (package != nil) ? [package path] : invisiblePathName;

  //NSLog( @"package = %@, filePath = %@, rootPath = %@", 
  //       [package name], filePath, rootPath);

  if ( [[NSWorkspace sharedWorkspace] 
           selectFile: filePath 
           inFileViewerRootedAtPath: rootPath] ) {
    // All went okay
    return;
  }
  
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];

  NSString  *msgFmt = 
    ( [fileToOpen isPackage]
      ? NSLocalizedString(@"Failed to reveal the package \"%@\"", 
                          @"Alert message")
      : ( [fileToOpen isDirectory] 
          ? NSLocalizedString(@"Failed to reveal the folder \"%@\"", 
                              @"Alert message")
          : NSLocalizedString(@"Failed to reveal the file \"%@\"", 
                              @"Alert message") ) );
  NSString  *msg = [NSString stringWithFormat: msgFmt, [fileToOpen name]];
  NSString  *info =
    NSLocalizedString(@"A possible reason is that it does not exist anymore.", 
                      @"Alert message (Note: the item can refer to a file or a folder)"); 
         
  [alert addButtonWithTitle: OK_BUTTON_TITLE];
  [alert setMessageText: msg];
  [alert setInformativeText: info];

  // TODO: Use a sheet instead?
  [alert runModal];
}


- (IBAction) deleteFile: (id) sender {
  FileItem  *selectedFile = [pathModelView selectedFileItem];
  BOOL  isDir = [selectedFile isDirectory];
  BOOL  isPackage = [selectedFile isPackage];

  // Packages whose contents are hidden (i.e. who are not represented as
  // directories) are treated schizophrenically for deletion: For deciding if
  // a confirmation message needs to be shown, they are treated as directories.
  // However, for determining if they can be deleted they are treated as files.

  if ( ( !(isDir || isPackage) && !confirmFileDeletion) ||
       (  (isDir || isPackage) && !confirmFolderDeletion) ) {
    // Delete the file/folder immediately, without asking for confirmation.
    [self deleteSelectedFile];
    
    return;
  }

  NSAlert  *alert = [[[NSAlert alloc] init] autorelease];
  NSString  *mainMsg;
  NSString  *infoMsg;
  NSString  *hardLinkMsg;

  if (isDir) {
    mainMsg = NSLocalizedString( @"Do you want to delete the folder \"%@\"?", 
                                 @"Alert message" );
    infoMsg = NSLocalizedString( 
      @"The selected folder, with all its contents, will be moved to Trash. Beware, any files in the folder that are not shown in the view will also be deleted.", 
      @"Alert informative text" );
    hardLinkMsg = NSLocalizedString( 
      @"Note: The folder is hard-linked. It will take up space until all links to it are deleted.",
      @"Alert additional informative text" );
  }
  else if (isPackage) {
    mainMsg = NSLocalizedString( @"Do you want to delete the package \"%@\"?", 
                                 @"Alert message" );
    infoMsg = NSLocalizedString( @"The selected package will be moved to Trash.", 
                                 @"Alert informative text" );
    hardLinkMsg = NSLocalizedString( 
      @"Note: The package is hard-linked. It will take up space until all links to it are deleted.",
      @"Alert additional informative text" );
  }
  else {
    mainMsg = NSLocalizedString( @"Do you want to delete the file \"%@\"?", 
                                 @"Alert message" );
    infoMsg = NSLocalizedString( @"The selected file will be moved to Trash.", 
                                 @"Alert informative text" );
    hardLinkMsg = NSLocalizedString( 
      @"Note: The file is hard-linked. It will take up space until all links to it are deleted.",
      @"Alert additional informative text" );
  }
  
  if ( [selectedFile isHardLinked] ) {
    infoMsg = [NSString stringWithFormat: @"%@\n\n%@", infoMsg, hardLinkMsg];
  }

  NSBundle  *mainBundle = [NSBundle mainBundle];
  
  [alert addButtonWithTitle: DELETE_BUTTON_TITLE];
  [alert addButtonWithTitle: CANCEL_BUTTON_TITLE];
  [alert setMessageText: [NSString stringWithFormat: mainMsg, 
                                     [[selectedFile name] lastPathComponent]]];
                                     // Note: using lastPathComponent, as the
                                     // scan tree item's name is relative to 
                                     // the volume root.
  [alert setInformativeText: infoMsg];

  [alert beginSheetModalForWindow: [self window] modalDelegate: self
           didEndSelector: @selector(confirmDeleteSelectedFileAlertDidEnd: 
                                       returnCode:contextInfo:) 
           contextInfo: nil];
}


- (IBAction) maskCheckBoxChanged:(id)sender {
  [self updateMask];
}

- (IBAction) editMask:(id)sender {
  if (editMaskFilterWindowControl == nil) {
    // Lazily create the "edit mask" window.
    
    [self createEditMaskFilterWindow];
  }
  
  [editMaskFilterWindowControl representFileItemTest:fileItemMask];

  // Note: First order it to front, then make it key. This ensures that
  // the maskWindowDidBecomeKey: does not move the DirectoryViewWindow to
  // the back.
  [[editMaskFilterWindowControl window] orderFront:self];
  [[editMaskFilterWindowControl window] makeKeyWindow];
}


- (IBAction) colorMappingChanged: (id) sender {
  UniqueTagsTransformer  *tagMaker = 
    [UniqueTagsTransformer defaultUniqueTagsTransformer];

  NSString  *name = 
    [tagMaker nameForTag: [[colorMappingPopUp selectedItem] tag]];
  NSObject <FileItemMappingScheme>  *mapping = 
    [colorMappings fileItemMappingSchemeForKey: name];

  if (mapping != nil) {
    NSObject <FileItemMapping>  *mapper = [mapping fileItemMapping];
  
    [mainView setTreeDrawerSettings: 
      [[mainView treeDrawerSettings] copyWithColorMapper: mapper]];
  }
}

- (IBAction) colorPaletteChanged: (id) sender {
  UniqueTagsTransformer  *tagMaker = 
    [UniqueTagsTransformer defaultUniqueTagsTransformer];
  NSString  *name = 
    [tagMaker nameForTag: [[colorPalettePopUp selectedItem] tag]];
  NSColorList  *palette = [colorPalettes colorListForKey: name];

  if (palette != nil) {  
    [mainView setTreeDrawerSettings: 
      [[mainView treeDrawerSettings] copyWithColorPalette: palette]];
  }
}

- (IBAction) showEntireVolumeCheckBoxChanged: (id) sender {
  [mainView setShowEntireVolume: [showEntireVolumeCheckBox state]==NSOnState];
}

- (IBAction) showPackageContentsCheckBoxChanged: (id) sender {
  BOOL  showPackageContents = [showPackageContentsCheckBox state]==NSOnState;
  
  [mainView setTreeDrawerSettings: 
    [[mainView treeDrawerSettings] copyWithShowPackageContents: 
       showPackageContents]];
  [[mainView pathModelView] setShowPackageContents: showPackageContents];

  // If the selected item is a package, its info will have changed.
  [self updateButtonState: nil];
}


+ (NSArray *) fileDeletionTargetNames {
  static NSArray  *fileDeletionTargetNames = nil;
  
  if (fileDeletionTargetNames == nil) {
    fileDeletionTargetNames = 
      [[NSArray arrayWithObjects: DeleteNothing, OnlyDeleteFiles, 
                                    DeleteFilesAndFolders, nil] retain];
  }
  
  return fileDeletionTargetNames;
}

@end // @implementation DirectoryViewControl


@implementation DirectoryViewControl (PrivateMethods)

- (BOOL) canRevealSelectedFile {
  return ([[pathModelView pathModel] isVisiblePathLocked] &&
          ![[pathModelView selectedFileItem] isSpecial]);
}

- (BOOL) canDeleteSelectedFile {
  FileItem  *selectedFile = [pathModelView selectedFileItem];

  return 
    ( [[pathModelView pathModel] isVisiblePathLocked] 

      // Special files cannot be deleted, as these are not actual files
      && ! [selectedFile isSpecial] 

      // Can this type of item be deleted (according to the preferences)?
      && ( (canDeleteFiles && ![selectedFile isDirectory])
           || (canDeleteFolders && [selectedFile isDirectory]) ) 

      // Can only delete the entire scan tree when it is an actual folder 
      // within the volume. You cannot delete the root folder.
      && ! ( (selectedFile == [pathModelView scanTree])
             && [[[pathModelView scanTree] name] isEqualToString: @""])
    );
}

- (void) confirmDeleteSelectedFileAlertDidEnd: (NSAlert *)alert 
           returnCode: (int) returnCode contextInfo: (void *)contextInfo {
  // Let the alert disappear, so that it is gone before the file is being
  // deleted as this can trigger another alert (namely when it fails).
  [[alert window] orderOut: self];
  
  if (returnCode == NSAlertFirstButtonReturn) {
    // Delete confirmed.
    
    [self deleteSelectedFile];
  }
}

- (void) deleteSelectedFile {
  FileItem  *selectedFile = [pathModelView selectedFileItem];

  NSWorkspace  *workspace = [NSWorkspace sharedWorkspace];
  NSString  *sourceDir = [[selectedFile parentDirectory] path];
    // Note: Can always obtain the encompassing directory this way. The 
    // volume tree cannot be deleted so there is always a valid parent
    // directory.
  int  tag;
  if ([workspace performFileOperation: NSWorkspaceRecycleOperation
                   source: sourceDir
                   destination: @""
                   files: [NSArray arrayWithObject: [selectedFile name]]
                   tag: &tag]) {
    [treeContext deleteSelectedFileItem: pathModelView];
  }
  else {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];

    NSString  *msgFmt = 
      ( [selectedFile isDirectory] 
        ? NSLocalizedString( @"Failed to delete the folder \"%@\"", 
                             @"Alert message")
        : NSLocalizedString( @"Failed to delete the file \"%@\"", 
                             @"Alert message") );
    NSString  *msg = [NSString stringWithFormat: msgFmt, [selectedFile name]];
    NSString  *info =
      NSLocalizedString(@"Possible reasons are that it does not exist anymore (it may have been moved, renamed, or deleted by other means) or that you lack the required permissions.", 
                        @"Alert message"); 
         
    [alert addButtonWithTitle: OK_BUTTON_TITLE];
    [alert setMessageText: msg];
    [alert setInformativeText: info];

    [alert runModal];
  }
}

- (void) fileItemDeleted: (NSNotification *)notification {
  [freedSpaceField setStringValue: 
                   [FileItem stringForFileItemSize: [treeContext freedSpace]]];
}


- (void) createEditMaskFilterWindow {  
  editMaskFilterWindowControl = [[EditFilterWindowControl alloc] init];

  [editMaskFilterWindowControl setAllowEmptyFilter: YES];

  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector: @selector(maskWindowApplyAction:)
        name: ApplyPerformedEvent object: editMaskFilterWindowControl];
  [nc addObserver:self selector: @selector(maskWindowCancelAction:)
        name: CancelPerformedEvent object: editMaskFilterWindowControl];
  [nc addObserver:self selector: @selector(maskWindowOkAction:)
        name: OkPerformedEvent object: editMaskFilterWindowControl];
  // Note: the ClosePerformedEvent notification can be ignored here.

  [nc addObserver:self selector:@selector(maskWindowDidBecomeKey:)
        name: NSWindowDidBecomeKeyNotification
        object: [editMaskFilterWindowControl window]];

  [[editMaskFilterWindowControl window] setTitle: 
      NSLocalizedString( @"Edit mask", @"Window title" ) ];
}

- (void) visibleTreeChanged:(NSNotification*)notification {
  FileItem  *visibleTree = [pathModelView visibleTree];
  
  [invisiblePathName release];
  invisiblePathName = [[visibleTree path] retain];

  [visibleFolderFocusControls showFileItem: visibleTree];

  [self updateButtonState: notification];
}


- (void) updateButtonState:(NSNotification*)notification {
  [upButton setEnabled: [pathModelView canMoveVisibleTreeUp]];
  [downButton setEnabled: [[pathModelView pathModel] isVisiblePathLocked] &&
                          [pathModelView canMoveVisibleTreeDown]];
  [openButton setEnabled: [self canRevealSelectedFile] ];
  [deleteButton setEnabled: [self canDeleteSelectedFile] ];
  
  FileItem  *selectedItem = [pathModelView selectedFileItem];

  if ( selectedItem != nil ) {
    ITEM_SIZE  itemSize = [selectedItem itemSize];
    NSString  *itemSizeString = [FileItem stringForFileItemSize: itemSize];

    [itemSizeField setStringValue: itemSizeString];

    NSString  *itemPath;
    NSString  *relativeItemPath;

    if ([selectedItem isSpecial]) {
      relativeItemPath = 
        [[NSBundle mainBundle] localizedStringForKey: [selectedItem name] 
                                 value: nil table: @"Names"];
      itemPath = relativeItemPath;
    }
    else {
      itemPath = [selectedItem path];
      
      NSAssert([itemPath hasPrefix: scanPathName], @"Invalid path prefix.");
      relativeItemPath = [itemPath substringFromIndex: [scanPathName length]];
      if ([relativeItemPath isAbsolutePath]) {
        // Strip leading slash.
        relativeItemPath = [relativeItemPath substringFromIndex: 1];
      }
      
      if ([itemPath hasPrefix: invisiblePathName]) {
        // Create attributed string for the path of the selected item. The
        // root of the scanned tree is excluded from the path, and the part 
        // that is inside the visible tree is marked using different
        // attributes.
    
        int  visLen = [itemPath length] - [invisiblePathName length] - 1;
        NSMutableAttributedString  *attributedPath = 
          [[[NSMutableAttributedString alloc] 
               initWithString: relativeItemPath] autorelease];
        if (visLen > 0) {
          [attributedPath addAttribute: NSForegroundColorAttributeName
                            value: [NSColor darkGrayColor] 
                            range: NSMakeRange([relativeItemPath length]-visLen, 
                                               visLen) ];
        }

        relativeItemPath = (NSString *)attributedPath;
      }
    }

    [itemPathField setStringValue: relativeItemPath];
    [selectedItemFocusControls 
       showFileItem: selectedItem itemPath: itemPath 
       sizeString: itemSizeString];
  }
  else {
    // There's no selected item
    [itemSizeField setStringValue: @""];
    [itemPathField setStringValue: @""];
    [selectedItemFocusControls clear];
  }
  
  // Update the file type fields in the Focus panel
  if ( selectedItem != nil && 
       ![selectedItem isSpecial] &&
       ![selectedItem isDirectory] ) {
    UniformType  *type = [ ((PlainFileItem *)selectedItem) uniformType];
    
    [selectedItemTypeIdentifierField 
       setStringValue: [type uniformTypeIdentifier]];
       
    [selectedItemTypeDescriptionField 
       setStringValue: ([type description] != nil ? [type description] : @"")];
  }
  else {
    [selectedItemTypeIdentifierField setStringValue: @""];
    [selectedItemTypeDescriptionField setStringValue: @""];
  }
}


- (void) maskChanged {
  if (fileItemMask != nil) {
    [maskCheckBox setEnabled: YES];
  }
  else {
    [maskCheckBox setEnabled: NO];
    [maskCheckBox setState: NSOffState];
  }
  
  [self updateMask];
}
  
- (void) updateMask {
  NSObject <FileItemTest>  *newMask = 
    [maskCheckBox state]==NSOnState ? fileItemMask : nil;

  [mainView setTreeDrawerSettings: 
    [[mainView treeDrawerSettings] copyWithFileItemMask: newMask]];
}


- (void) updateFileDeletionSupport {
  NSUserDefaults  *userDefaults = [NSUserDefaults standardUserDefaults];
  
  NSString  *fileDeletionTargets = 
    [userDefaults stringForKey: FileDeletionTargetsKey];

  canDeleteFiles = 
    ([fileDeletionTargets isEqualToString: OnlyDeleteFiles] ||
     [fileDeletionTargets isEqualToString: DeleteFilesAndFolders]);
  canDeleteFolders =
     [fileDeletionTargets isEqualToString: DeleteFilesAndFolders];
  confirmFileDeletion = 
    [[userDefaults objectForKey: ConfirmFileDeletionKey] boolValue];
  confirmFolderDeletion = 
    [[userDefaults objectForKey: ConfirmFolderDeletionKey] boolValue];

  [deleteButton setEnabled: [self canDeleteSelectedFile] ];
}


- (void) maskWindowApplyAction:(NSNotification*)notification {
  [fileItemMask release];
  
  fileItemMask = [[editMaskFilterWindowControl createFileItemTest] retain];

  if (fileItemMask != nil) {
    // Automatically enable mask.
    [maskCheckBox setState: NSOnState];
  }
  
  [self maskChanged];
}

- (void) maskWindowCancelAction:(NSNotification*)notification {
  [[editMaskFilterWindowControl window] close];
}

- (void) maskWindowOkAction:(NSNotification*)notification {
  [[editMaskFilterWindowControl window] close];
  
  // Other than closing the window, the action is same as the "apply" one.
  [self maskWindowApplyAction:notification];
}

- (void) maskWindowDidBecomeKey:(NSNotification*)notification {
  [[self window] orderWindow:NSWindowBelow
               relativeTo:[[editMaskFilterWindowControl window] windowNumber]];
  [[self window] makeMainWindow];
}

@end // @implementation DirectoryViewControl (PrivateMethods)


@implementation ItemInFocusControls

- (id) initWithPathTextView: (NSTextView *)pathTextViewVal
         titleField: (NSTextField *)titleFieldVal
         exactSizeField: (NSTextField *)exactSizeFieldVal
         sizeField: (NSTextField *)sizeFieldVal {
  if (self = [super init]) {
    pathTextView = [pathTextViewVal retain];
    titleField = [titleFieldVal retain];
    exactSizeField = [exactSizeFieldVal retain];
    sizeField = [sizeFieldVal retain];
  }

  return self;
}

- (void) dealloc {
  [titleField release];
  [pathTextView release];
  [exactSizeField release];
  [sizeField release];
  
  [super dealloc];
}


- (void) clear {
  [titleField setStringValue: [self titleForFileItem: nil]];
  [pathTextView setString: @""];
  [exactSizeField setStringValue: @""];
  [sizeField setStringValue: @""];
}


- (void) showFileItem: (FileItem *)item {
  NSString  *sizeString = [FileItem stringForFileItemSize: [item itemSize]];
  NSString  *itemPath = 
    ( [item isSpecial] 
      ? [[NSBundle mainBundle] localizedStringForKey: [item name] 
                                 value: nil table: @"Names"]
      : [item path] );
    
  [self showFileItem: item itemPath: itemPath sizeString: sizeString];
}


- (void) showFileItem: (FileItem *)item itemPath: (NSString *)pathString
           sizeString: (NSString *)sizeString {
  [titleField setStringValue: [self titleForFileItem: item]];
  
  [pathTextView setString: pathString];
  [exactSizeField setStringValue: 
     [FileItem exactStringForFileItemSize: [item itemSize]]];
  [sizeField setStringValue: [NSString stringWithFormat: @"(%@)", sizeString]];
       
  // Use the color of the size fields to show if the item is hard-linked.
  NSColor  *sizeFieldColor = ([item isHardLinked] 
                              ? [NSColor darkGrayColor]
                              : [titleField textColor]);
  [exactSizeField setTextColor: sizeFieldColor];
  [sizeField setTextColor: sizeFieldColor];
}


- (NSString *) titleForFileItem: (FileItem *)item {
  NSAssert(NO, @"Abstract method");
}

@end // @implementation ItemInFocusControls


@implementation FolderInViewFocusControls

- (NSString *) titleForFileItem: (FileItem *)item {
  if ( [item isSpecial] ) {
    return NSLocalizedString( @"Area in view:", "Label in Focus panel" );
  }
  else if ( [item isPackage] ) {
    return NSLocalizedString( @"Package in view:", "Label in Focus panel" );
  }
  else if ( [item isDirectory] ) {
    return NSLocalizedString( @"Folder in view:", "Label in Focus panel" );
  }
  else { // Default, also used when item == nil
    return NSLocalizedString( @"File in view:", "Label in Focus panel" );
  }
}

@end // @implementation FolderInViewFocusControls


@implementation SelectedItemFocusControls

- (NSString *) titleForFileItem: (FileItem *)item {
  if ( [item isSpecial] ) {
    return NSLocalizedString( @"Selected area:", "Label in Focus panel" );
  }
  else if ( [item isPackage] ) {
    return NSLocalizedString( @"Selected package:", "Label in Focus panel" );
  }
  else if ( [item isDirectory] ) {
    return NSLocalizedString( @"Selected folder:", "Label in Focus panel" );
  }
  else { // Default, also used when item == nil
    return NSLocalizedString( @"Selected file:", "Label in Focus panel" );
  }
}

@end // @implementation SelectedItemFocusControls


