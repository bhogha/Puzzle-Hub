// LocalNotifications — native iOS local-notification scheduling for Puzzle Hub.
// Schedules a single repeating daily reminder ("Your daily puzzle is ready!").
// Tapping it just opens the app (no custom actions/categories are registered).

#import <UIKit/UIKit.h>                      // NSObject / NSString / app types
#import <UserNotifications/UserNotifications.h>   // UNUserNotificationCenter etc.

@interface LocalNotifications : NSObject

// Request authorization (once) and (re)schedule the daily 9:30 AM reminder.
- (double) notif_setup_daily_puzzle;

// Remove the scheduled daily reminder.
- (double) notif_cancel_all;

@end
