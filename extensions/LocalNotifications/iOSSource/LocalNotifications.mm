#import "LocalNotifications.h"

// ── Tunables ─────────────────────────────────────────────────────────────────
// The reminder's copy lives here. The TIMING is now driven from GML (scr_notify)
// so the reminder can be synced to the Daily Spin's cooldown: the function is
// passed the number of seconds to wait. Keep the identifier stable so
// re-scheduling replaces the existing request instead of stacking duplicates.
//
//   seconds  > 0  → fire once, that many seconds from now (one-shot).
//   seconds == 0  → fire every day at PH_NOTIF_HOUR:PH_NOTIF_MINUTE (repeating).
//   seconds  < 0  → schedule nothing (just cancel any pending reminder).
#define PH_NOTIF_ID     @"daily_puzzle_ready"
#define PH_NOTIF_HOUR   9
#define PH_NOTIF_MINUTE 30
#define PH_NOTIF_TITLE  @"Puzzle Hub"
#define PH_NOTIF_BODY   @"Your daily spin is ready!"

@implementation LocalNotifications

// Request authorization (the iOS system prompt appears only the first time the
// user is asked) and, if granted, (re)schedule the reminder according to `seconds`
// (see the contract above). Safe to call on every launch / spin claim — the
// request with PH_NOTIF_ID is removed and re-added, so there's never more than one
// pending reminder.
- (double) notif_setup_daily_puzzle:(double)seconds {
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        UNAuthorizationOptions opts =
            UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;

        [center requestAuthorizationWithOptions:opts
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!granted) return;

            // Always clear the previous pending reminder first.
            [center removePendingNotificationRequestsWithIdentifiers:@[PH_NOTIF_ID]];

            // Negative → caller wants nothing scheduled (e.g. the spin is already
            // available, so there's nothing to remind about).
            if (seconds < 0) return;

            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = PH_NOTIF_TITLE;
            content.body  = PH_NOTIF_BODY;
            content.sound = [UNNotificationSound defaultSound];

            id trigger;
            if (seconds > 0.5) {
                // One-shot: fire `seconds` from now (synced to the spin cooldown).
                trigger = [UNTimeIntervalNotificationTrigger
                              triggerWithTimeInterval:seconds repeats:NO];
            } else {
                // Daily reminder at the configured local time (repeats:YES).
                NSDateComponents *when = [[NSDateComponents alloc] init];
                when.hour   = PH_NOTIF_HOUR;
                when.minute = PH_NOTIF_MINUTE;
                trigger = [UNCalendarNotificationTrigger
                              triggerWithDateMatchingComponents:when repeats:YES];
            }

            UNNotificationRequest *request =
                [UNNotificationRequest requestWithIdentifier:PH_NOTIF_ID
                                                     content:content
                                                     trigger:trigger];
            [center addNotificationRequest:request withCompletionHandler:nil];
        }];
    }
    return 1.0;
}

// Cancel the scheduled reminder (handy if a Settings toggle is added later).
- (double) notif_cancel_all {
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center removePendingNotificationRequestsWithIdentifiers:@[PH_NOTIF_ID]];
    }
    return 1.0;
}

@end
