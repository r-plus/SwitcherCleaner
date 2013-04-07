#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwitcherCleaner.plist"

static BOOL cleanerIsEnabled;
static BOOL removeRecentsIsEnabled;
static BOOL quitButtonIsEnabled;
static BOOL swipeUpToCloseIsEnabled;
static BOOL longPressToCloseAllAppsIsEnabled;
static BOOL excludeNowPlayingApp;

static int (*BKSTerminateApplicationForReasonAndReportWithDescription)(NSString *displayIdentifier, int reason, int something, int something2);

@interface SBProcess : NSObject // SBProcess class is dead in iOS 6+
- (BOOL)isRunning;
@end
@interface SBApplication : NSObject
@property(retain, nonatomic) SBProcess* process;// until iOS 5
- (BOOL)isRunning;// iOS 6+
- (NSString *)bundleIdentifier;
@end
@interface SBApplicationIcon : NSObject
- (SBApplication *)application;
@end
@interface SBIconModel : NSObject
- (SBApplicationIcon *)applicationIconForDisplayIdentifier:(NSString *)identifier;
@end
@interface SBIcon : NSObject
- (SBApplication *)application;
@end
@interface SBIconView : UIView
@property(readonly, retain) SBIcon* icon;
- (int)location;
- (void)setShowsCloseBox:(BOOL)show animated:(BOOL)animate;
@end
@interface SBAppSwitcherBarView : UIView
- (CGPoint)_firstPageOffset:(CGSize)offset;
- (SBIconView *)visibleIconViewForDisplayIdentifier:(NSString *)identifier;
- (SBIcon *)_iconForDisplayIdentifier:(id)displayIdentifier;
- (SBIconView *)_iconViewForIcon:(id)icon creatingIfNecessary:(BOOL)necessary;
- (void)removeIconWithDisplayIdentifier:(id)displayIdentifier;
@end
@interface SBIconViewMap : NSObject
+ (id)switcherMap;
- (SBIconModel *)iconModel;
@end
@interface SBAppSwitcherController : NSObject
- (NSArray *)_applicationIconsExceptTopApp;// iOS 5
- (NSArray *)_bundleIdentifiersForViewDisplay;// iOS 6+
- (void)iconCloseBoxTapped:(SBIconView *)iconView;
@end
@interface SpringBoard : UIApplication
- (SBApplication *)nowPlayingApp;
@end
@interface UISwipeGestureRecognizer (Private)
@property float minimumPrimaryMovement;// 50.0f
@property float maximumPrimaryMovement;// too large
@property float minimumSecondaryMovement;// 0.0f
@property float maximumSecondaryMovement;// 50.0f
@end

%hook SBAppSwitcherController
// iOS 5.x
- (NSArray *)_applicationIconsExceptTopApp
{
    NSMutableArray *runningApps = [NSMutableArray array];

    for (SBIconView *iconView in %orig) {
        if (cleanerIsEnabled && removeRecentsIsEnabled) {
            if ([[iconView.icon application].process isRunning])
                [runningApps addObject:iconView];
        } else {
            [runningApps addObject:iconView];
        }
    }

    return runningApps;
}

// iOS 6.x
- (NSArray *)_bundleIdentifiersForViewDisplay
{
    NSMutableArray *runningApps = [NSMutableArray array];
    SBIconModel *iconModel = [[%c(SBIconViewMap) switcherMap] iconModel];
    for (NSString *identifier in %orig) {
        SBApplicationIcon *icon = [iconModel applicationIconForDisplayIdentifier:identifier];
        if (cleanerIsEnabled && removeRecentsIsEnabled) {
            if ([[icon application] isRunning])
                [runningApps addObject:identifier];
        } else {
            [runningApps addObject:identifier];
        }
    }
    return runningApps;
}

static inline void SetCloseBoxAndGesture(id self, SBIconView *iconView)
{
    if (iconView) {
        if (quitButtonIsEnabled)
            [iconView setShowsCloseBox:YES animated:YES];
        if (swipeUpToCloseIsEnabled) {
            UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpToClose:)];
            swipe.direction = UISwipeGestureRecognizerDirectionUp;
            [iconView addGestureRecognizer:swipe];
            [swipe release];
        }
        if (longPressToCloseAllAppsIsEnabled) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressToCloseAllApps:)];
            [iconView addGestureRecognizer:longPress];
            [longPress release];
        }
    }
}

- (void)viewWillAppear
{
    %orig;
    if (cleanerIsEnabled) {
        if ([self respondsToSelector:@selector(_applicationIconsExceptTopApp)]) {
            // iOS 5.x
            for (id iconView in [self _applicationIconsExceptTopApp]) {
                SetCloseBoxAndGesture(self, iconView);
            }
        } else if ([self respondsToSelector:@selector(_bundleIdentifiersForViewDisplay)]) {
            // iOS 6.x
            SBAppSwitcherBarView *barView = MSHookIvar<SBAppSwitcherBarView *>(self, "_bottomBar");
            for (NSString *identifier in [self _bundleIdentifiersForViewDisplay]) {
                SBIconView *iconView = [barView visibleIconViewForDisplayIdentifier:identifier];
                SetCloseBoxAndGesture(self, iconView);
            }
        }
    }
}

%new(v@:@)
- (void)swipeUpToClose:(UISwipeGestureRecognizer *)gesture
{
    if (cleanerIsEnabled && swipeUpToCloseIsEnabled)
        [self iconCloseBoxTapped:(SBIconView *)gesture.view];
}

%new(v@:@)
- (void)longPressToCloseAllApps:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan)
        return;

    if (cleanerIsEnabled && longPressToCloseAllAppsIsEnabled) {
        if ([self respondsToSelector:@selector(_applicationIconsExceptTopApp)]) {
            // iOS 5.x
            for (SBIconView *iconView in [self _applicationIconsExceptTopApp]) {
                [self iconCloseBoxTapped:iconView];
            }
        } else if ([self respondsToSelector:@selector(_bundleIdentifiersForViewDisplay)]) {
            // iOS 6.x
            NSString *nowPlayingAppID = [[(SpringBoard *)[UIApplication sharedApplication] nowPlayingApp] bundleIdentifier];
            SBAppSwitcherBarView *barView = MSHookIvar<SBAppSwitcherBarView *>(self, "_bottomBar");
            for (NSString *identifier in [self _bundleIdentifiersForViewDisplay]) {
                SBIcon *icon = [barView _iconForDisplayIdentifier:identifier];
                SBIconView *iconView = [barView _iconViewForIcon:icon creatingIfNecessary:YES];
                if (iconView) {
                    if (excludeNowPlayingApp) {
                        if (![[[icon application] bundleIdentifier] isEqualToString:nowPlayingAppID])
                            [self iconCloseBoxTapped:iconView];
                    } else {
                        [self iconCloseBoxTapped:iconView];
                    }
                } else if (BKSTerminateApplicationForReasonAndReportWithDescription != NULL) {
                    // for future compatibility.
                    BKSTerminateApplicationForReasonAndReportWithDescription(identifier, 1, 0, 0);
                    [barView removeIconWithDisplayIdentifier:identifier];
                }
            }
            // Workaround for Zephyr: When long press app that existing 2+ page location to close all app, Zephyr will not work on SpringBoard.
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Zephyr.dylib"]) {
                CGPoint firstPagePoint = [barView _firstPageOffset:[UIScreen mainScreen].applicationFrame.size];
                firstPagePoint.x += 1;
                UIScrollView *sv = MSHookIvar<UIScrollView *>(barView, "_scrollView");
                [sv setContentOffset:firstPagePoint animated:NO];
            }
        }
    }
}
%end

%hook SBIconView
- (void)setShowsCloseBox:(BOOL)arg animated:(BOOL)anima
{
    // location 0 == HomeScreen, 1 == Dock, 2 == AppSwitcher.
    if (cleanerIsEnabled && quitButtonIsEnabled && [self location] == 2)
        %orig(YES, YES);
    else
        %orig;
}
%end

static void LoadSettings()
{	
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    id existEnabled = [dict objectForKey:@"Enabled"];
    cleanerIsEnabled = existEnabled ? [existEnabled boolValue] : YES;
    id existRR = [dict objectForKey:@"RemoveRecents"];
    removeRecentsIsEnabled = existRR ? [existRR boolValue] : YES;
    id existQB = [dict objectForKey:@"QuitButton"];
    quitButtonIsEnabled = existQB ? [existQB boolValue] : YES;
    id existSU = [dict objectForKey:@"SwipeUpToClose"];
    swipeUpToCloseIsEnabled = existSU ? [existSU boolValue] : YES;
    id existLP = [dict objectForKey:@"LongPressToCloseAll"];
    longPressToCloseAllAppsIsEnabled = existLP ? [existLP boolValue] : YES;
    id excludeNowPlayingAppPref = [dict objectForKey:@"ExcludeNowPlayingApp"];
    excludeNowPlayingApp = excludeNowPlayingAppPref ? [excludeNowPlayingAppPref boolValue] : NO;
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    LoadSettings();
}

%ctor
{
    @autoreleasepool {
        void *bk = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (bk) {
            BKSTerminateApplicationForReasonAndReportWithDescription = (int (*)(NSString*, int, int, int))dlsym(bk, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("jp.r-plus.SwitcherCleaner.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        LoadSettings();
    }
}
