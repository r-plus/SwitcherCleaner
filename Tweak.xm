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

static inline void SetCloseBoxAndSwipeUpGesture(id self, SBIconView *iconView)
{
  if (iconView) {
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpToClose:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [iconView setShowsCloseBox:YES animated:YES];
    [iconView addGestureRecognizer:swipe];
    [swipe release];
  }
}

- (void)viewWillAppear
{
  %orig;
  if ([self respondsToSelector:@selector(_applicationIconsExceptTopApp)]) {
    // iOS 5.x
    for (id iconView in [self _applicationIconsExceptTopApp]) {
      SetCloseBoxAndSwipeUpGesture(self, iconView);
    }
  } else if ([self respondsToSelector:@selector(_bundleIdentifiersForViewDisplay)]) {
    // iOS 6.x
    SBAppSwitcherBarView *barView = MSHookIvar<SBAppSwitcherBarView *>(self, "_bottomBar");
    for (NSString *identifier in [self _bundleIdentifiersForViewDisplay]) {
      SBIconView *iconView = [barView visibleIconViewForDisplayIdentifier:identifier];
      SetCloseBoxAndSwipeUpGesture(self, iconView);
    }
  }
}

%new(v@:@)
- (void)swipeUpToClose:(UISwipeGestureRecognizer *)gesture
{
  [self iconCloseBoxTapped:(SBIconView *)gesture.view];
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
