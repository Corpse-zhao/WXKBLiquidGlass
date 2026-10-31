#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// UIInputSetContainerView 是私有类，iOS SDK 里没有声明。
// 不补这一句，Logos 生成的钩子会因为找不到类定义而编译失败 / 静默失效。
@interface UIInputSetContainerView : UIView
@end

static NSString * const kTargetBundleID = @"com.tencent.wetype.keyboard";
static NSString * const kVersion = @"1.0.0";
static const void *kGlassViewKey = &kGlassViewKey;
static const void *kOriginalBackgroundColorKey = &kOriginalBackgroundColorKey;
static const void *kOriginalOpaqueKey = &kOriginalOpaqueKey;

static UIVisualEffectView *WXKBGlassView(UIView *view) {
    return (UIVisualEffectView *)objc_getAssociatedObject(view, kGlassViewKey);
}

static void WXKBApplyGlass(UIView *view) {
    if (!view || !view.window || WXKBGlassView(view)) return;

    // Keep the blur behind keyboard keys and preserve hit testing.
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
    glass.userInteractionEnabled = NO;
    glass.accessibilityElementsHidden = YES;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.frame = view.bounds;
    glass.layer.cornerRadius = 16.0;
    glass.clipsToBounds = YES;

    objc_setAssociatedObject(view, kGlassViewKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, kOriginalBackgroundColorKey, view.backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, kOriginalOpaqueKey, @(view.opaque), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    view.backgroundColor = UIColor.clearColor;
    view.opaque = NO;
    [view insertSubview:glass atIndex:0];
}

static void WXKBLayoutGlass(UIView *view) {
    UIVisualEffectView *glass = WXKBGlassView(view);
    if (glass) {
        if (!CGRectEqualToRect(glass.frame, view.bounds)) glass.frame = view.bounds;
        if (view.subviews.firstObject != glass) [view sendSubviewToBack:glass];
    }
}

%group WXKBKeyboard

%hook UIInputView

- (void)didMoveToWindow {
    %orig;
    WXKBApplyGlass(self);
}

- (void)layoutSubviews {
    %orig;
    WXKBApplyGlass(self);
    WXKBLayoutGlass(self);
}

%end

%hook UIInputSetContainerView

- (void)didMoveToWindow {
    %orig;
    // The container is sometimes used as the visible keyboard surface.
    WXKBApplyGlass(self);
}

- (void)layoutSubviews {
    %orig;
    WXKBApplyGlass(self);
    WXKBLayoutGlass(self);
}

%end

%end

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        if ([bundleID isEqualToString:kTargetBundleID]) {
            NSLog(@"[WXKBLiquidGlass] 已注入 %@ (v%@)", bundleID, kVersion);
            %init(WXKBKeyboard);
        }
    }
}
