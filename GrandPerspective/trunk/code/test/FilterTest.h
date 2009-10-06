#import <Cocoa/Cocoa.h>

/* A test that can be part of a FileItemFilter.
 */
@interface FilterTest : NSObject {
  NSString  *name;

  // Is the test inverted?
  BOOL  inverted;
  
  // Can the inverted state be changed?
  BOOL  canToggleInverted;
}

+ (id) filterTestWithName:(NSString *)name;

- (id) initWithName:(NSString *)name;

- (NSString *) name;
- (BOOL) isInverted;

- (void) setCanToggleInverted:(BOOL) flag;
- (BOOL) canToggleInverted;

- (void) toggleInverted;

@end
