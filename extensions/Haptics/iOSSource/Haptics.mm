#import "Haptics.h"

// Long-lived generators for the high-frequency effects (selection ticks during a
// spin / drag, and notifications). Keeping them around + calling -prepare keeps
// the Taptic Engine warm so repeated ticks stay crisp and low-latency. Impact
// generators are created per call so each can carry its own style.
static UISelectionFeedbackGenerator    *gSelection    = nil;
static UINotificationFeedbackGenerator *gNotification = nil;

@implementation Haptics

- (double) haptic_prepare {
    if (@available(iOS 10.0, *)) {
        if (gSelection == nil)    gSelection    = [[UISelectionFeedbackGenerator alloc] init];
        if (gNotification == nil) gNotification = [[UINotificationFeedbackGenerator alloc] init];
        [gSelection prepare];
        [gNotification prepare];
    }
    return 0;
}

- (double) haptic_impact:(double)style {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackStyle s = UIImpactFeedbackStyleMedium;
        int v = (int)style;
        if (v == 0)      s = UIImpactFeedbackStyleLight;
        else if (v == 1) s = UIImpactFeedbackStyleMedium;
        else if (v == 2) s = UIImpactFeedbackStyleHeavy;
        else if (v == 3) { if (@available(iOS 13.0, *)) s = UIImpactFeedbackStyleSoft;  }
        else if (v == 4) { if (@available(iOS 13.0, *)) s = UIImpactFeedbackStyleRigid; }
        UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:s];
        [g prepare];
        [g impactOccurred];
    }
    return 0;
}

- (double) haptic_notification:(double)type {
    if (@available(iOS 10.0, *)) {
        if (gNotification == nil) gNotification = [[UINotificationFeedbackGenerator alloc] init];
        UINotificationFeedbackType t = UINotificationFeedbackTypeSuccess;
        int v = (int)type;
        if (v == 1)      t = UINotificationFeedbackTypeWarning;
        else if (v == 2) t = UINotificationFeedbackTypeError;
        [gNotification notificationOccurred:t];
        [gNotification prepare];   // re-arm for the next one
    }
    return 0;
}

- (double) haptic_selection {
    if (@available(iOS 10.0, *)) {
        if (gSelection == nil) gSelection = [[UISelectionFeedbackGenerator alloc] init];
        [gSelection selectionChanged];
        [gSelection prepare];      // re-arm for the next tick
    }
    return 0;
}

@end
