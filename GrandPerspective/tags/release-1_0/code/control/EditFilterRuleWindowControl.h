#import <Cocoa/Cocoa.h>

@protocol FileItemTest;
@class StringMatchControls;
@class TypeMatchControls;

@interface EditFilterRuleWindowControl : NSWindowController {

  IBOutlet NSTextField  *ruleNameField;
  IBOutlet NSPopUpButton  *ruleTargetPopUp;
  
  IBOutlet NSButton  *nameCheckBox;
  IBOutlet NSPopUpButton  *nameMatchPopUpButton;
  IBOutlet NSTableView  *nameTargetsView;
  IBOutlet NSButton  *nameCaseInsensitiveCheckBox;
  IBOutlet NSButton  *addNameTargetButton;
  IBOutlet NSButton  *removeNameTargetButton;
  
  IBOutlet NSButton  *pathCheckBox;
  IBOutlet NSPopUpButton  *pathMatchPopUpButton;
  IBOutlet NSTableView  *pathTargetsView;
  IBOutlet NSButton  *pathCaseInsensitiveCheckBox;
  IBOutlet NSButton  *addPathTargetButton;
  IBOutlet NSButton  *removePathTargetButton;
  
  IBOutlet NSButton  *hardLinkCheckBox;
  IBOutlet NSPopUpButton  *hardLinkStatusPopUp;

  IBOutlet NSButton  *packageCheckBox;
  IBOutlet NSPopUpButton  *packageStatusPopUp;

  IBOutlet NSButton  *typeCheckBox;
  IBOutlet NSPopUpButton  *typeMatchPopUpButton;
  IBOutlet NSTableView  *typeTargetsView;
  IBOutlet NSButton  *addTypeTargetButton;
  IBOutlet NSButton  *removeTypeTargetButton;
  
  IBOutlet NSButton  *sizeLowerBoundCheckBox;
  IBOutlet NSTextField  *sizeLowerBoundField;
  IBOutlet NSPopUpButton  *sizeLowerBoundUnits;

  IBOutlet NSButton  *sizeUpperBoundCheckBox;
  IBOutlet NSTextField  *sizeUpperBoundField;
  IBOutlet NSPopUpButton  *sizeUpperBoundUnits;

  IBOutlet NSButton  *cancelButton;
  IBOutlet NSButton  *doneButton;
  
  NSString  *ruleName;
  
  TypeMatchControls  *typeTestControls;
  StringMatchControls  *nameTestControls;
  StringMatchControls  *pathTestControls;
}

+ (id) defaultInstance;

- (IBAction) valueEntered:(id)sender;

- (IBAction) targetPopUpChanged:(id)sender;

- (IBAction) nameCheckBoxChanged:(id)sender;
- (IBAction) pathCheckBoxChanged:(id)sender;
- (IBAction) hardLinkCheckBoxChanged:(id)sender;
- (IBAction) packageCheckBoxChanged:(id)sender;
- (IBAction) typeCheckBoxChanged:(id)sender;
- (IBAction) lowerBoundCheckBoxChanged:(id)sender;
- (IBAction) upperBoundCheckBoxChanged:(id)sender;

- (IBAction) addNameTarget: (id) sender;
- (IBAction) removeNameTarget: (id) sender;

- (IBAction) addPathTarget: (id) sender;
- (IBAction) removePathTarget: (id) sender;

- (IBAction) addTypeTarget: (id) sender;
- (IBAction) removeTypeTarget: (id) sender;

- (IBAction) updateEnabledState:(id)sender;

- (IBAction) cancelAction:(id)sender;
- (IBAction) okAction:(id)sender;

- (NSString*) fileItemTestName;

/* Configures the window to represent the given test.
 */
- (void) representFileItemTest:(NSObject <FileItemTest> *)test;

/* Creates the test object that represents the current window state.
 */
- (NSObject <FileItemTest> *) createFileItemTest;

/* Sets the name of the rule as it is shown in the window. This may be
 * different from the actual name of the rule (in particular, the visible
 * name may be localized). Once a visible name is set, it cannot be changed.
 */
- (void) setVisibleName: (NSString *)name;

@end
