#import <UIKit/UIKit.h>

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

  for (SBIconView *iconView in %orig)
    if ([[iconView.icon application].process isRunning])
      [runningApps addObject:iconView];

  return runningApps;
}

// iOS 6.x
- (NSArray *)_bundleIdentifiersForViewDisplay
{
  NSMutableArray *runningApps = [NSMutableArray array];
  SBIconModel *iconModel = [[%c(SBIconViewMap) switcherMap] iconModel];
  for (NSString *identifier in %orig) {
    SBApplicationIcon *icon = [iconModel applicationIconForDisplayIdentifier:identifier];
    if (icon)
      if ([[icon application] isRunning])
        [runningApps addObject:identifier];
  }
  return runningApps;
}

static inline void SetCloseBoxAndGesture(id self, SBIconView *iconView)
{
  if (iconView) {
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpToClose:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [iconView setShowsCloseBox:YES animated:YES];
    [iconView addGestureRecognizer:swipe];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressToCloseAllApps:)];
    [iconView addGestureRecognizer:longPress];
    [swipe release];
    [longPress release];
  }
}

- (void)viewWillAppear
{
  %orig;
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

%new(v@:@)
- (void)swipeUpToClose:(UISwipeGestureRecognizer *)gesture
{
  [self iconCloseBoxTapped:(SBIconView *)gesture.view];
}

%new(v@:@)
- (void)longPressToCloseAllApps:(UILongPressGestureRecognizer *)gesture
{
  if ([self respondsToSelector:@selector(_applicationIconsExceptTopApp)]) {
    // iOS 5.x
    for (SBIconView *iconView in [self _applicationIconsExceptTopApp]) {
      [self iconCloseBoxTapped:iconView];
    }
  } else if ([self respondsToSelector:@selector(_bundleIdentifiersForViewDisplay)]) {
    // iOS 6.x
    SBAppSwitcherBarView *barView = MSHookIvar<SBAppSwitcherBarView *>(self, "_bottomBar");
    for (NSString *identifier in [self _bundleIdentifiersForViewDisplay]) {
      SBIconView *iconView = [barView visibleIconViewForDisplayIdentifier:identifier];
      [self iconCloseBoxTapped:iconView];
    }
  }
}
%end

%hook SBIconView
- (void)setShowsCloseBox:(BOOL)arg animated:(BOOL)anima
{
  // location 0 == HomeScreen, 1 == Dock, 2 == AppSwitcher.
  if ([self location] == 2)
    %orig(YES, YES);
  else
    %orig;
}
%end
