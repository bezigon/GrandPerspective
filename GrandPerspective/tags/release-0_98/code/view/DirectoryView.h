#import <Cocoa/Cocoa.h>

@class AsynchronousTaskManager;
@class TreeLayoutBuilder;
@class ItemPathDrawer;
@class ItemPathBuilder;
@class ItemPathModel;
@class FileItemHashing;
@protocol FileItemTest;

@interface DirectoryView : NSView {
  AsynchronousTaskManager  *drawTaskManager;

  TreeLayoutBuilder  *treeLayoutBuilder;
  ItemPathDrawer  *pathDrawer;
  ItemPathBuilder  *pathBuilder;
  
  ItemPathModel  *pathModel;
  
  NSImage  *treeImage;  
}

- (void) setItemPathModel:(ItemPathModel*)itemPath;
- (ItemPathModel*) itemPathModel;

- (void) setColorMapping:(FileItemHashing *)colorMapping;
- (FileItemHashing*) colorMapping;

- (void) setColorPalette:(NSColorList *)colorPalette;
- (NSColorList*) colorPalette;

- (void) setFileItemMask:(NSObject <FileItemTest>*)fileItemMask;
- (NSObject <FileItemTest> *) fileItemMask;

@end
