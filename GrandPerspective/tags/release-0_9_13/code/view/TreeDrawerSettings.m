#import "TreeDrawerSettings.h"

#import "StatelessFileItemMapping.h"


@interface TreeDrawerSettings (PrivateMethods)

+ (NSColorList *) defaultColorPalette;

@end


@implementation TreeDrawerSettings

// Creates default settings.
- (id) init {
  return 
    [self initWithColorMapper: 
                          [[[StatelessFileItemMapping alloc] init] autorelease]
            colorPalette: [TreeDrawerSettings defaultColorPalette]
            fileItemMask: nil
            showPackageContents: YES];
}


- (id) initWithColorMapper: (NSObject <FileItemMapping> *)colorMapperVal
         colorPalette: (NSColorList *)colorPaletteVal
         fileItemMask: (NSObject <FileItemTest> *)fileItemMaskVal
         showPackageContents: (BOOL) showPackageContentsVal {
  if (self = [super init]) {
    colorMapper = [colorMapperVal retain];
    colorPalette = [colorPaletteVal retain];
    fileItemMask = [fileItemMaskVal retain];
    showPackageContents = showPackageContentsVal;
  }
  
  return self;
}

- (void) dealloc {
  [colorMapper release];
  [colorPalette release];
  [fileItemMask release];
  
  [super dealloc];  
}


- (id) copyWithColorMapper: (NSObject <FileItemMapping> *)colorMapperVal {
  return [[[TreeDrawerSettings alloc]
              initWithColorMapper: colorMapperVal
              colorPalette: colorPalette
              fileItemMask: fileItemMask
              showPackageContents: showPackageContents] autorelease];
}

- (id) copyWithColorPalette: (NSColorList *)colorPaletteVal {
  return [[[TreeDrawerSettings alloc]
              initWithColorMapper: colorMapper
              colorPalette: colorPaletteVal
              fileItemMask: fileItemMask
              showPackageContents: showPackageContents] autorelease];
}

- (id) copyWithFileItemMask: (NSObject<FileItemTest> *)fileItemMaskVal {
  return [[[TreeDrawerSettings alloc]
              initWithColorMapper: colorMapper
              colorPalette: colorPalette
              fileItemMask: fileItemMaskVal
              showPackageContents: showPackageContents] autorelease];
}

- (id) copyWithShowPackageContents: (BOOL) showPackageContentsVal {
  return [[[TreeDrawerSettings alloc]
              initWithColorMapper: colorMapper
              colorPalette: colorPalette
              fileItemMask: fileItemMask
              showPackageContents: showPackageContentsVal] autorelease];
}

- (NSObject <FileItemMapping> *) colorMapper {
  return colorMapper;
}

- (NSColorList *) colorPalette {
  return colorPalette;
}

- (NSObject <FileItemTest> *) fileItemMask {
  return fileItemMask;
}

- (BOOL) showPackageContents {
  return showPackageContents;
}

@end // @implementation TreeDrawerSettings


NSColorList  *defaultColorPalette = nil;

@implementation TreeDrawerSettings (PrivateMethods)

+ (NSColorList *) defaultColorPalette {
  if (defaultColorPalette==nil) {
    NSColorList  *colorList =
      [[NSColorList alloc] initWithName: @"DefaultTreeDrawerPalette"];

    [colorList insertColor: [NSColor blueColor]    key: @"blue"    atIndex: 0];
    [colorList insertColor: [NSColor redColor]     key: @"red"     atIndex: 1];
    [colorList insertColor: [NSColor greenColor]   key: @"green"   atIndex: 2];
    [colorList insertColor: [NSColor cyanColor]    key: @"cyan"    atIndex: 3];
    [colorList insertColor: [NSColor magentaColor] key: @"magenta" atIndex: 4];
    [colorList insertColor: [NSColor orangeColor]  key: @"orange"  atIndex: 5];
    [colorList insertColor: [NSColor yellowColor]  key: @"yellow"  atIndex: 6];
    [colorList insertColor: [NSColor purpleColor]  key: @"purple"  atIndex: 7];

    defaultColorPalette = colorList;
  }

  return defaultColorPalette;
}

@end // @implementation TreeDrawerSettings (PrivateMethods)
