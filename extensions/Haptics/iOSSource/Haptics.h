// Haptics — native iOS tactile feedback for Puzzle Hub.
// Thin wrapper over UIKit's feedback generators (Taptic Engine). The GML side
// (scr_haptics) decides WHICH effect fires for each game event and gates on the
// player's haptics_on save flag; this just relays the call to UIKit.
//
// All four functions return a double (0) so they fit GameMaker's extension ABI;
// the return value is unused. Generators only do anything on devices with a
// Taptic Engine (iPhone 7+) running iOS 10+ — older devices / the simulator are
// silent, never an error.

#import <UIKit/UIKit.h>   // UIFeedbackGenerator family, NSObject, CGFloat

@interface Haptics : NSObject

// Pre-warm the feedback generators so the first real buzz has no latency.
- (double) haptic_prepare;

// UIImpactFeedbackGenerator. style: 0=light 1=medium 2=heavy 3=soft 4=rigid
// (soft/rigid require iOS 13; they fall back to medium on older systems).
- (double) haptic_impact:(double)style;

// UINotificationFeedbackGenerator. type: 0=success 1=warning 2=error
- (double) haptic_notification:(double)type;

// UISelectionFeedbackGenerator — the light "tick" used for wheel slices / drags.
- (double) haptic_selection;

@end
