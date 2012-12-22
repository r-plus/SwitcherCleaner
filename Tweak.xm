#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwitcherCleaner.plist"

static BOOL cleanerIsEnabled;
static BOOL removeRecentsIsEnabled;
static BOOL quitButtonIsEnabled;
static BOOL swipeUpToCloseIsEnabled;
static BOOL longPressToCloseAllAppsIsEnabled;

@interface SBProcess : NSObject // SBProcess class is dead in iOS 6+
- (BOOL)isRunning;
@end
@interface SBApplication : NSObject
@property(retain, nonatomic) SBProcess* process;// until iOS 5
- (BOOL)isRunning;// iOS 6+
@end
@interface SBApplicationIcon : NSObject
- (SBApplication *)application;
@end
@interface SBIconModel : NSObject
- (SBApplicationIcon *)applicationIconForDisplayIdentifier:(NSString *)identifier;
@end
@interface SBIcon : NSObject
- (SBApplication *)application;
-(id)applicationBundleID;
@end
@interface SBIconView : UIView
@property(readonly, retain) SBIcon* icon;
- (int)location;
- (void)setShowsCloseBox:(BOOL)show animated:(BOOL)animate;
@end
@interface SBAppSwitcherBarView : NSObject
- (SBIconView *)visibleIconViewForDisplayIdentifier:(NSString *)identifier;
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
  if (cleanerIsEnabled && longPressToCloseAllAppsIsEnabled) {
    if ([self respondsToSelector:@selector(_applicationIconsExceptTopApp)]) {
      // iOS 5.x
      for (SBIconView *iconView in [self _applicationIconsExceptTopApp]) {
        NSString *identifier = [iconView.icon applicationBundleID];
        if (![identifier isEqualToString:@"com.apple.mobileipod"] && ![identifier isEqualToString:@"com.apple.Music"])
          [self iconCloseBoxTapped:iconView];
      }
    } else if ([self respondsToSelector:@selector(_bundleIdentifiersForViewDisplay)]) {
      // iOS 6.x
      SBAppSwitcherBarView *barView = MSHookIvar<SBAppSwitcherBarView *>(self, "_bottomBar");
      for (NSString *identifier in [self _bundleIdentifiersForViewDisplay]) {
        SBIconView *iconView = [barView visibleIconViewForDisplayIdentifier:identifier];
        // iOS 5+ iPhone: com.apple.mobileipod
        // iOS 5 iPad: com.apple.Music
        if (![identifier isEqualToString:@"com.apple.mobileipod"] && ![identifier isEqualToString:@"com.apple.Music"])
          [self iconCloseBoxTapped:iconView];
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
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  LoadSettings();
}

%ctor
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("jp.r-plus.SwitcherCleaner.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
  LoadSettings();
  [pool drain];
}
