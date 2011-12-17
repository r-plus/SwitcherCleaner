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
  for (id iconView in [self _applicationIconsExceptTopApp])
    [iconView setShowsCloseBox:YES];
}
%end
