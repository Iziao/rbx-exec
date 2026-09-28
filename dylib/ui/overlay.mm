#import "overlay.h"
#import <QuartzCore/QuartzCore.h>

@interface CobbleOverlay ()
@property (nonatomic, strong) UIWindow*       window;
@property (nonatomic, strong) UIView*         panel;
@property (nonatomic, strong) UIView*         titleBar;
@property (nonatomic, strong) UITextView*     editor;
@property (nonatomic, strong) UITextView*     console;
@property (nonatomic, strong) UIButton*       runButton;
@property (nonatomic, strong) UIButton*       hideButton;
@property (nonatomic, strong) UIButton*       restoreButton;
@property (nonatomic, strong) UIPanGestureRecognizer* pan;
@property (nonatomic, assign) CGPoint         panStart;
@end

@implementation CobbleOverlay

+ (instancetype)shared {
    static CobbleOverlay* inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [CobbleOverlay new]; });
    return inst;
}

- (UIWindowScene*)activeScene {
    for (UIScene* s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene*)s;
    }
    return nil;
}

- (void)present {
    if (self.window) { self.window.hidden = NO; return; }

    UIWindowScene* scene = [self activeScene];
    if (!scene) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                       dispatch_get_main_queue(), ^{ [self present]; });
        return;
    }

    CGRect screen = scene.coordinateSpace.bounds;
    self.window = [[UIWindow alloc] initWithWindowScene:scene];
    self.window.windowLevel = UIWindowLevelAlert + 100;
    self.window.backgroundColor = UIColor.clearColor;
    UIViewController* root = [UIViewController new];
    root.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = root;
    self.window.hidden = NO;

    CGFloat w = screen.size.width  * 0.90;
    CGFloat h = screen.size.height * 0.68;
    CGRect panelFrame = CGRectMake((screen.size.width  - w) / 2,
                                   (screen.size.height - h) / 2, w, h);

    self.panel = [[UIView alloc] initWithFrame:panelFrame];
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.masksToBounds = YES;
    self.panel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleBottomMargin |
                                  UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleRightMargin;

    UIVisualEffectView* blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = self.panel.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:blur];

    CGFloat barH = 46;
    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, barH)];
    self.titleBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    self.titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.panel addSubview:self.titleBar];

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 80, barH)];
    title.text = @"cobble hills";
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textColor = UIColor.whiteColor;
    [self.titleBar addSubview:title];

    self.hideButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.hideButton.frame = CGRectMake(w - 46, 0, 46, barH);
    self.hideButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.hideButton setTitle:@"×" forState:UIControlStateNormal];
    self.hideButton.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightLight];
    [self.hideButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.hideButton addTarget:self action:@selector(hideTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:self.hideButton];

    CGFloat pad     = 10;
    CGFloat footerH = 46;
    CGFloat consoleH = 130;
    CGFloat editorH = h - barH - pad * 3 - footerH - consoleH;

    self.editor = [[UITextView alloc] initWithFrame:CGRectMake(
        pad, barH + pad, w - pad * 2, editorH)];
    self.editor.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    self.editor.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.editor.textColor = UIColor.whiteColor;
    self.editor.font = [UIFont fontWithName:@"Menlo" size:12] ?:
                       [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.editor.layer.cornerRadius = 10;
    self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.smartQuotesType = UITextSmartQuotesTypeNo;
    self.editor.smartDashesType = UITextSmartDashesTypeNo;
    self.editor.keyboardAppearance = UIKeyboardAppearanceDark;
    self.editor.text = @"-- cobble hills mobile\nprint(\"hello from roblox\")\n";
    [self.panel addSubview:self.editor];

    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(
        pad, h - pad - consoleH - pad - footerH, w - pad * 2, footerH);
    self.runButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                      UIViewAutoresizingFlexibleWidth;
    [self.runButton setTitle:@"Execute" forState:UIControlStateNormal];
    [self.runButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.runButton.backgroundColor =
        [UIColor colorWithRed:0.13 green:0.65 blue:0.30 alpha:1.0];
    self.runButton.layer.cornerRadius = 10;
    [self.runButton addTarget:self action:@selector(runTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.runButton];

    self.console = [[UITextView alloc] initWithFrame:CGRectMake(
        pad, h - pad - consoleH, w - pad * 2, consoleH)];
    self.console.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleWidth;
    self.console.editable = NO;
    self.console.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
    self.console.textColor = [UIColor colorWithRed:0.65 green:1.0 blue:0.65 alpha:1.0];
    self.console.font = [UIFont fontWithName:@"Menlo" size:11] ?:
                        [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.console.layer.cornerRadius = 10;
    self.console.text = @"[ready]\n";
    [self.panel addSubview:self.console];

    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                       action:@selector(panned:)];
    [self.titleBar addGestureRecognizer:self.pan];

    self.restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.restoreButton.frame = CGRectMake(screen.size.width - 60, 90, 48, 48);
    self.restoreButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.restoreButton.layer.cornerRadius = 24;
    [self.restoreButton setTitle:@"C" forState:UIControlStateNormal];
    [self.restoreButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.restoreButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.restoreButton.hidden = YES;
    [self.restoreButton addTarget:self action:@selector(restoreTapped)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.window.rootViewController.view addSubview:self.panel];
    [self.window.rootViewController.view addSubview:self.restoreButton];
}

- (void)hideTapped {
    self.panel.hidden = YES;
    self.restoreButton.hidden = NO;
    [self.editor resignFirstResponder];
}

- (void)restoreTapped {
    self.panel.hidden = NO;
    self.restoreButton.hidden = YES;
}

- (void)runTapped {
    [self.editor resignFirstResponder];
    if (self.onRun) self.onRun(self.editor.text ?: @"");
}

- (void)panned:(UIPanGestureRecognizer*)g {
    CGPoint t = [g translationInView:self.window];
    if (g.state == UIGestureRecognizerStateBegan) {
        self.panStart = self.panel.center;
    } else if (g.state == UIGestureRecognizerStateChanged) {
        self.panel.center = CGPointMake(self.panStart.x + t.x,
                                        self.panStart.y + t.y);
    }
}

- (void)appendOutput:(NSString*)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* cur = self.console.text ?: @"";
        self.console.text = [cur stringByAppendingFormat:@"%@\n", text];
        if (self.console.text.length > 1) {
            NSRange end = NSMakeRange(self.console.text.length - 1, 1);
            [self.console scrollRangeToVisible:end];
        }
    });
}

@end
