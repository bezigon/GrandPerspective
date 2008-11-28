#import <Cocoa/Cocoa.h>


extern NSString  *ToolbarNavigateUp;
extern NSString  *ToolbarNavigateDown; 
extern NSString  *ToolbarOpenItem;
extern NSString  *ToolbarDeleteItem;
extern NSString  *ToolbarToggleInfoDrawer;


@class DirectoryViewControl;

@interface DirectoryViewToolbarControl : NSObject {

  IBOutlet NSWindow  *dirViewWindow;

  IBOutlet NSView  *navigationView;
  IBOutlet NSView  *selectionView;
  IBOutlet NSSegmentedControl  *navigationControls;
  IBOutlet NSSegmentedControl  *selectionControls;

  DirectoryViewControl  *dirView;

}

- (IBAction) navigationAction: (id) sender;
- (IBAction) selectionAction: (id) sender;

@end
