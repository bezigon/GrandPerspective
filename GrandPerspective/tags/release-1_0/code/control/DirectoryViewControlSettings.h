#import <Cocoa/Cocoa.h>


@protocol FileItemTest;


@interface DirectoryViewControlSettings : NSObject {
  NSString  *colorMappingKey;
  NSString  *colorPaletteKey;
  NSObject <FileItemTest>  *mask;
  BOOL  maskEnabled;
  BOOL  showEntireVolume;
  BOOL  showPackageContents;
  
  // The window's size when it is unzoomed. This is considered its real size
  // setting. When the window is zoomed, the maximum size is only a temporary 
  // state.
  NSSize  unzoomedViewSize;
}

- (id) initWithColorMappingKey: (NSString *)colorMappingKey 
         colorPaletteKey: (NSString *)colorPaletteKey
         mask: (NSObject <FileItemTest> *)mask
         maskEnabled: (BOOL) maskEnabled
         showEntireVolume: (BOOL) showEntireVolume
         showPackageContents: (BOOL) showPackageContents
         unzoomedViewSize: (NSSize) viewSize;

- (NSString*) colorMappingKey;
- (void) setColorMappingKey: (NSString *)key;

- (NSString*) colorPaletteKey;
- (void) setColorPaletteKey: (NSString *)key;

- (NSObject <FileItemTest>*) fileItemMask;
- (void) setFileItemMask: (NSObject <FileItemTest> *)mask;

- (BOOL) fileItemMaskEnabled;
- (void) setFileItemMaskEnabled: (BOOL)flag;

- (BOOL) showEntireVolume;
- (void) setShowEntireVolume: (BOOL)flag;

- (BOOL) showPackageContents;
- (void) setShowPackageContents: (BOOL)flag;

- (NSSize) unzoomedViewSize;
- (void) setunzoomedViewSize: (NSSize) size;

@end
