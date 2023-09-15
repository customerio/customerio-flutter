enum Screen {
  // Used for screens that are not configured in GoRouter
  undefined(name: '', path: ''),
  login(name: 'Login', path: '/login'),
  // For GoRouter, initial path must be `/`
  dashboard(name: 'Dashboard', path: '/'),
  // Used for supporting dashboard path in deep links
  dashboardRedirect(name: 'DashboardRedirect', path: 'dashboard'),
  settings(name: 'Settings', path: 'settings'),
  customEvents(name: 'Custom Event', path: 'events/custom'),
  deviceAttributes(name: 'Custom Device Attribute', path: 'attributes/device'),
  profileAttributes(
      name: 'Custom Profile Attribute', path: 'attributes/profile');

  const Screen({
    required this.name,
    required this.path,
  });

  // Required by GoRouter, should be unique and non-empty
  final String name;

  // Required by GoRouter, should be unique and non-empty
  final String path;

  String get location {
    // Since login is not configured inside dashboard, we not need to modify its path
    if (this == Screen.dashboard || this == Screen.login) {
      return path;
    } else {
      // Since all other screens are configured inside dashboard, we need to
      // prepend dashboard path to them
      return '${dashboard.path}$path';
    }
  }
}

extension ScreenProperties on Screen {
  /// Returns true if screen requires user to be authenticated to view it.
  bool get isAuthenticatedViewOnly =>
      !isUnauthenticatedViewOnly && !isPublicViewAllowed;

  /// Returns true if screen can be viewed without authentication.
  bool get isUnauthenticatedViewOnly => this == Screen.login;

  /// Returns true if screen can be viewed by both authenticated and unauthenticated users.
  bool get isPublicViewAllowed => this == Screen.settings;
}

extension RouterPathProperties on String {
  Screen? toAppScreen() => ScreenFactory.fromRouterLocation(this);
}

extension ScreenFactory on Screen {
  /// Creates a screen from router location.
  /// Falls back to [Screen.undefined] if no screen is found.
  static Screen? fromRouterLocation(String location) {
    Screen screen = Screen.values
        // Exclude screen that are not configured our have children
        .where((screen) =>
            screen != Screen.dashboard && screen != Screen.undefined)
        .firstWhere((screen) => location.startsWith(screen.location),
            orElse: () => Screen.undefined);

    // If screen is found, return it
    if (screen != Screen.undefined) {
      return screen;
      // Else, check if location is dashboard, then return dashboard
    } else if (location.startsWith(Screen.dashboard.location)) {
      return Screen.dashboard;
    }
    // Else, no screen found, return null
    return null;
  }
}
