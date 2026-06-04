#import <Cocoa/Cocoa.h>

// Private AppKit method that pins a Touch Bar item into the system tray /
// Control Strip so it is visible regardless of the frontmost app.
@interface NSTouchBarItem (PrivateControlStrip)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
@end

// Private AppKit methods that present an NSTouchBar across the full bar
// (the approach MTMR/Pock use for wide, persistent content).
@interface NSTouchBar (PrivateModal)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
          systemTrayItemIdentifier:(NSTouchBarItemIdentifier _Nullable)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;
@end

// Private DFRFoundation entry points for Control Strip presence.
extern void DFRElementSetControlStripPresenceForIdentifier(NSString *identifier, BOOL present);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);
