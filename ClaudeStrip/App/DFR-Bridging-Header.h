#import <Cocoa/Cocoa.h>

// Private AppKit method that pins a Touch Bar item into the system tray /
// Control Strip so it is visible regardless of the frontmost app.
@interface NSTouchBarItem (PrivateControlStrip)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
@end

// Private DFRFoundation entry points for Control Strip presence.
extern void DFRElementSetControlStripPresenceForIdentifier(NSString *identifier, BOOL present);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);
