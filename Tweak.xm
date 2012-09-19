#import <UIKit/UIKit.h>

%hook SBAppSwitcherController
- (id)_applicationIconsExceptTopApp
{
  NSMutableArray *runningApps = [NSMutableArray array];

  for (id iconView in %orig)
    if ([[[[iconView icon] application] process] isRunning])
      [runningApps addObject:iconView];

  return runningApps;
}

- (void)viewWillAppear
{
  %orig;
  for (id iconView in [self _applicationIconsExceptTopApp]) {
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUpToClose:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [iconView setShowsCloseBox:YES];
    [iconView addGestureRecognizer:swipe];
    [swipe release];
  }
}

%new(v@:@)
- (void)swipeUpToClose:(UISwipeGestureRecognizer *)gesture
{
  [self iconCloseBoxTapped:gesture.view];
}
%end
