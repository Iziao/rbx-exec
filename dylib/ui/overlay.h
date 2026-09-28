#import <UIKit/UIKit.h>

@interface CobbleOverlay : NSObject
@property (nonatomic, copy) void (^onRun)(NSString* script);
+ (instancetype)shared;
- (void)present;
- (void)appendOutput:(NSString*)text;
@end
