#import <Cocoa/Cocoa.h>

@class AsynchronousTaskManager;
@class TreeLayoutBuilder;
@class FileItem;
@class ItemTreeDrawerSettings;
@class ItemPathDrawer;
@class ItemPathBuilder;
@class ItemPathModel;

@interface DirectoryView : NSView {
  AsynchronousTaskManager  *drawTaskManager;

  // Even though layout builder could also be considered part of the
  // itemTreeDrawerSettings, it is maintained here, as it is also needed by
  // the pathDrawer, and other objects.
  TreeLayoutBuilder  *layoutBuilder;
  
  ItemPathDrawer  *pathDrawer;
  ItemPathBuilder  *pathBuilder;
  
  ItemPathModel  *pathModel;
  
  // Maintains the selected item if it is outside the visible tree (in which
  // case it cannot be maintained by the pathModel). This can happen when the
  // entire volume is shown.
  FileItem  *invisibleSelectedItem;
  
  BOOL  showEntireVolume;
  
  NSImage  *treeImage;
  
  float  scrollWheelDelta;
}

// Initialises the instance-specific state after the view has been restored
// from the nib file (which invokes the generic initWithFrame: method).
- (void) postInitWithPathModel: (ItemPathModel *)pathModelVal;

- (ItemPathModel *)itemPathModel;
- (FileItem *)treeInView;
- (FileItem *)selectedItem;

- (ItemTreeDrawerSettings *) treeDrawerSettings;
- (void) setTreeDrawerSettings: (ItemTreeDrawerSettings *)settings;

- (BOOL) showEntireVolume;
- (void) setShowEntireVolume: (BOOL) flag;

- (TreeLayoutBuilder*) layoutBuilder;

@end
