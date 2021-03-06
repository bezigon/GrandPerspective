#import "FileItemHashingOptions.h"

#import "DirectoryItem.h" // Imports FileItem.h
#import "FileItemHashing.h"

@interface HashingByDepth : FileItemHashing {
}
@end

@interface HashingByExtension : FileItemHashing {
}
@end

@interface HashingByFilename : FileItemHashing {
}
@end

@interface HashingByDirectoryName : FileItemHashing {
}
@end

@interface HashingByTopDirectoryName : FileItemHashing {
}
@end

@implementation HashingByDepth

- (int) hashForFileItem:(FileItem*)item depth:(int)depth {
  return depth;
}

@end // @implementation HashingByDepth


@implementation HashingByExtension

- (int) hashForFileItem:(FileItem*)item depth:(int)depth {
  return [[[item name] pathExtension] hash];
}

@end // @implementation HashingByExtension


@implementation HashingByFilename

- (int) hashForFileItem:(FileItem*)item depth:(int)depth {
  return [[item name] hash];
}

@end // @implementation HashingByFilename


@implementation HashingByDirectoryName

- (int) hashForFileItem:(FileItem*)item depth:(int)depth {
  return [[[item parentDirectory] name] hash];
}

@end // @implementation HashingByDirectoryName 


@implementation HashingByTopDirectoryName

- (int) hashForFileItem:(FileItem*)item depth:(int)depth {
  DirectoryItem  *dir = [item parentDirectory];
  int  i = depth-2;

  while (--i >= 0) {
    dir = [dir parentDirectory];
  }

  return [[dir name] hash];
}

@end // @implementation HashingByTopDirectoryName 


@implementation FileItemHashingOptions

FileItemHashingOptions  *defaultFileItemHashingOptions = nil;

+ (FileItemHashingOptions*) defaultFileItemHashingOptions {
  if (defaultFileItemHashingOptions==nil) {
    defaultFileItemHashingOptions = [[FileItemHashingOptions alloc] init];
  }
  
  return defaultFileItemHashingOptions;
}

// Uses a default set of five coloring options.
// Overrides super's designated initialiser.
- (id) init {
  NSMutableDictionary  *colorings = 
    [NSMutableDictionary dictionaryWithCapacity:6];

  [colorings setObject:[[[HashingByTopDirectoryName alloc] init] autorelease]
               forKey:@"top folder"];
  [colorings setObject:[[[HashingByDirectoryName alloc] init] autorelease]
               forKey:@"folder"];
  [colorings setObject:[[[HashingByExtension alloc] init] autorelease]
               forKey:@"extension"];
  [colorings setObject:[[[HashingByFilename alloc] init] autorelease]
               forKey:@"name"];
  [colorings setObject:[[[HashingByDepth alloc] init] autorelease]
               forKey:@"depth"];
  [colorings setObject:[[[FileItemHashing alloc] init] autorelease]
               forKey:@"nothing"];

  return [self initWithDictionary:colorings defaultKey:@"folder"];
}

- (id) initWithDictionary:(NSDictionary*)dictionary {
  // Init with arbitrary key as default
  return [self initWithDictionary:dictionary 
                 defaultKey:[[dictionary keyEnumerator] nextObject]];
}

- (id) initWithDictionary:(NSDictionary*)dictionary defaultKey:defaultKeyVal {
  if (self = [super init]) {
    optionsDictionary = [dictionary retain];
    defaultKey = [defaultKeyVal retain];
  }
  return self;
}

- (void) dealloc {
  [optionsDictionary release];
  [defaultKey release];
  
  [super dealloc];
}

- (NSArray*) allKeys {
  return [optionsDictionary allKeys];
}

- (NSString*) keyForDefaultHashing {
  return defaultKey;
}

- (FileItemHashing*) fileItemHashingForKey:(NSString*)key {
  return [optionsDictionary objectForKey:key];
}

@end // @implementation FileItemHashingOptions
