// Block definition

#import <UIKit/UIKit.h>   // declares NSObject, NSString, CGFloat, UIApplication/UIWindow

@interface iOSSafeArea : NSObject {
    CGFloat topPadding;
    CGFloat bottomPadding;
    CGFloat leftPadding;
    CGFloat rightPadding;
}

@property (nonatomic) CGFloat topPadding;
@property (nonatomic) CGFloat bottomPadding;
@property (nonatomic) CGFloat leftPadding;
@property (nonatomic) CGFloat rightPadding;

- (NSString *) iOS_get_safe_area;
@end
