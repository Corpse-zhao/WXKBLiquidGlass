#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 私有类：SDK 里没有声明，不补就编不过 / 钩子静默失效
@interface UIInputSetHostView : UIView
@end
@interface UIInputSetContainerView : UIView
@end

static NSString * const kTargetBundleID = @"com.tencent.wetype.keyboard";
static NSString * const kVersion = @"1.1.0";

#pragma mark - 视图判据

// 子树里真的有按键内容（Keyplane / KeyView / KeyboardLayout）
static BOOL WXKBContainsKeyContent(UIView *view, NSUInteger depth) {
    if (!view || depth > 4) return NO;
    for (UIView *sub in view.subviews) {
        NSString *n = NSStringFromClass(sub.class);
        if ([n containsString:@"Keyplane"] || [n containsString:@"KeyView"] ||
            [n containsString:@"KeyboardLayout"] || [n containsString:@"KeyCap"]) return YES;
        if (WXKBContainsKeyContent(sub, depth + 1)) return YES;
    }
    return NO;
}

// 背板判定：类名带 Backdrop + 铺满屏宽 + 子树里没有按键内容（有按键就绝不能藏，否则键盘哑掉）
static BOOL WXKBIsSafeBackdrop(UIView *view, CGFloat screenWidth) {
    if (!view) return NO;
    NSString *n = NSStringFromClass(view.class);
    if (![n containsString:@"Backdrop"]) return NO;
    if (view.frame.size.width < screenWidth * 0.8) return NO;
    if (WXKBContainsKeyContent(view, 0)) return NO;
    return YES;
}

// 键盘尺寸资格（宽度铺满 + 高度够）
static BOOL WXKBIsKeyboardSized(UIView *view) {
    if (!view || !view.superview) return NO;
    CGFloat screenWidth = view.window ? view.window.bounds.size.width : 0;
    if (screenWidth <= 0) screenWidth = UIScreen.mainScreen.bounds.size.width;
    if (view.frame.size.width < screenWidth * 0.85) return NO;
    return view.frame.size.height >= 110.0;
}

#pragma mark - 安装器

@interface WXKBInstaller : NSObject
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *savedBackdropAlpha;
@property (nonatomic, copy) NSString *lastSignature;
@end

@implementation WXKBInstaller

+ (instancetype)shared {
    static WXKBInstaller *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [WXKBInstaller new]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        _savedBackdropAlpha = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory
                                                   valueOptions:NSPointerFunctionsStrongMemory];
    }
    return self;
}

- (UIVisualEffectView *)makeGlass {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
    glass.userInteractionEnabled = NO;             // 关键：绝不吃触摸
    glass.accessibilityElementsHidden = YES;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // veil：背板被藏了，底色全靠这一层撑住，否则按键文字看不清
    UIView *veil = [[UIView alloc] init];
    veil.userInteractionEnabled = NO;
    veil.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.30];
    veil.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    veil.tag = 9701;
    [glass.contentView addSubview:veil];
    glass.layer.cornerRadius = 12.0;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    glass.layer.borderWidth = 0.5;
    glass.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    return glass;
}

// 递归找背板；命中即停止下钻（藏外层连带藏内层，避免父子都记状态）
- (NSArray<UIView *> *)backdropsIn:(UIView *)host screenWidth:(CGFloat)screenWidth {
    NSMutableArray<UIView *> *found = [NSMutableArray array];
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:host];
    NSUInteger guard = 0;
    while (queue.count > 0 && guard++ < 3000) {
        UIView *cur = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (!cur) continue;
        if (cur != host && WXKBIsSafeBackdrop(cur, screenWidth)) {
            [found addObject:cur];
            continue;
        }
        [queue addObjectsFromArray:cur.subviews];
    }
    return found;
}

- (void)installInHost:(UIView *)host {
    if (!host || !host.window) return;
    if (!WXKBIsKeyboardSized(host)) {
        self.glass.hidden = YES;
        return;
    }

    CGFloat screenWidth = host.window.bounds.size.width;
    NSArray<UIView *> *backdrops = [self backdropsIn:host screenWidth:screenWidth];

    // 选面积最大的那块当锚
    UIView *anchor = nil;
    CGFloat best = 0;
    for (UIView *bg in backdrops) {
        CGFloat a = bg.frame.size.width * bg.frame.size.height;
        if (a > best) { best = a; anchor = bg; }
    }

    NSString *sig = [NSString stringWithFormat:@"%@|%.0fx%.0f|%lu",
                     NSStringFromClass(host.class), host.frame.size.width, host.frame.size.height,
                     (unsigned long)backdrops.count];
    BOOL sameLayout = [sig isEqualToString:self.lastSignature];

    if (!self.glass) self.glass = [self makeGlass];
    UIView *parent = anchor ? anchor.superview : host;
    if (!parent) return;

    // 隐藏原生背板（记原值，可恢复）
    NSUInteger hiddenCount = 0;
    for (UIView *bg in backdrops) {
        if (!bg) continue;
        NSNumber *saved = [self.savedBackdropAlpha objectForKey:bg];
        if (!saved) {
            [self.savedBackdropAlpha setObject:@(bg.alpha) forKey:bg];
            saved = @(bg.alpha);
        }
        if (bg.alpha != 0.0) { bg.alpha = 0.0; hiddenCount++; }
    }

    // 宿主的底色也清掉（背板之外的纯 backgroundColor 情况）
    host.backgroundColor = UIColor.clearColor;
    host.opaque = NO;

    if (self.glass.superview != parent) [self.glass removeFromSuperview];

    // 先放到锚点上面，再纠正 z 序：玻璃必须在「所有背景之上、所有按键之下」
    if (anchor) [parent insertSubview:self.glass aboveSubview:anchor];
    else        [parent insertSubview:self.glass atIndex:0];

    UIView *fg = nil;
    for (UIView *sub in parent.subviews) {
        if (sub != self.glass && WXKBContainsKeyContent(sub, 0)) fg = sub;   // 取最靠上的按键层
    }
    if (fg && self.glass.superview == parent) {
        NSInteger gi = [parent.subviews indexOfObject:self.glass];
        NSInteger fi = [parent.subviews indexOfObject:fg];
        if (gi != NSNotFound && fi != NSNotFound && gi > fi) {
            [parent insertSubview:self.glass belowSubview:fg];
        }
    }

    self.glass.frame = parent.bounds;
    UIView *veil = [self.glass.contentView viewWithTag:9701];
    veil.frame = self.glass.contentView.bounds;
    self.glass.hidden = NO;

    if (!sameLayout) {
        self.lastSignature = sig;
        NSMutableString *roles = [NSMutableString string];
        for (UIView *sub in parent.subviews) {
            NSString *role = (sub == self.glass) ? @"GLASS" : (WXKBContainsKeyContent(sub, 0) ? @"keys" : @"bg?");
            [roles appendFormat:@"[%ld]%@:%@ ", (long)[parent.subviews indexOfObject:sub],
             NSStringFromClass(sub.class), role];
        }
        NSLog(@"[WXKBLiquidGlass] v%@ install host=%@ parent=%@ backdrops=%lu hidden=%lu | %@",
              kVersion, NSStringFromClass(host.class), NSStringFromClass(parent.class),
              (unsigned long)backdrops.count, (unsigned long)hiddenCount, roles);
    }
}

// 全窗口扫一遍，找键盘尺寸的容器
- (void)scan {
    static BOOL scanning = NO;
    if (scanning) return;
    scanning = YES;

    NSMutableArray<UIView *> *queue = [NSMutableArray array];
    for (UIWindow *w in UIApplication.sharedApplication.windows) [queue addObject:w];

    NSUInteger guard = 0;
    UIView *bestHost = nil;
    while (queue.count > 0 && guard++ < 1500) {
        UIView *cur = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (!cur) continue;
        NSString *cn = NSStringFromClass(cur.class);
        BOOL isInputHost = [cur isKindOfClass:[UIInputView class]] ||
                           [cn containsString:@"InputSetHost"] || [cn containsString:@"InputSetContainer"];
        if (isInputHost && WXKBIsKeyboardSized(cur)) {
            if (!bestHost || cur.frame.size.height > bestHost.frame.size.height) bestHost = cur;
            continue;
        }
        for (UIView *sub in cur.subviews) [queue addObject:sub];
    }

    if (bestHost) [self installInHost:bestHost];
    scanning = NO;
}

@end

#pragma mark - Hooks

%group WXKBKeyboard

%hook UIInputView

- (void)didMoveToWindow {
    %orig;
    [[WXKBInstaller shared] scan];
}

- (void)layoutSubviews {
    %orig;
    static BOOL inLayout = NO;
    if (inLayout) return;
    inLayout = YES;
    [[WXKBInstaller shared] installInHost:self];
    inLayout = NO;
}

%end

%hook UIInputSetHostView

- (void)layoutSubviews {
    %orig;
    static BOOL inLayout = NO;
    if (inLayout) return;
    inLayout = YES;
    [[WXKBInstaller shared] installInHost:self];
    inLayout = NO;
}

%end

%hook UIInputSetContainerView

- (void)layoutSubviews {
    %orig;
    [[WXKBInstaller shared] scan];
}

%end

%end

#pragma mark - 入口

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        if ([bundleID isEqualToString:kTargetBundleID]) {
            NSLog(@"[WXKBLiquidGlass] v%@ 已注入 %@", kVersion, bundleID);
            %init(WXKBKeyboard);

            // 键盘视图可能晚于 %ctor 建树：多补几次扫描，并跟随键盘通知
            for (NSNumber *delay in @[@0.4, @1.2, @2.5]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    [[WXKBInstaller shared] scan];
                });
            }
            [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification
                                                              object:nil
                                                               queue:NSOperationQueue.mainQueue
                                                          usingBlock:^(NSNotification *note) {
                [[WXKBInstaller shared] scan];
            }];
        }
    }
}
