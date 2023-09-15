import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth.dart';
import 'color_schemes.g.dart';
import 'customer_io.dart';
import 'data/screen.dart';
import 'screens/attributes.dart';
import 'screens/dashboard.dart';
import 'screens/events.dart';
import 'screens/login.dart';
import 'screens/settings.dart';
import 'theme/sizes.dart';
import 'utils/logs.dart';

/// Main entry point of AmiApp
class AmiApp extends StatefulWidget {
  final AmiAppAuth auth;

  const AmiApp({required this.auth, Key? key}) : super(key: key);

  @override
  State<AmiApp> createState() => _AmiAppState();
}

/// App state that holds states for authentication, navigation and Customer.io SDK
class _AmiAppState extends State<AmiApp> {
  final CustomerIOSDK _customerIOSDK = CustomerIOSDKInstance.get();
  late final GoRouter _router;

  AmiAppAuth get _auth => widget.auth;

  final PageTransitionsTheme _pageTransitionsTheme = const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );
  final List<ThemeExtension<dynamic>> _themeExtensions = [
    const Sizes.defaults(),
  ];

  Future<void> _initCustomerIO() => _customerIOSDK
          .initialize()
          .whenComplete(
              () => debugLog('Customer.io SDK initialization successful'))
          .catchError((error) {
        debugLog('Customer.io SDK could not be initialized:  $error');
      });

  @override
  void initState() {
    // GoRouter configurations.
    _router = GoRouter(
      debugLogDiagnostics: true,
      initialLocation: Screen.dashboard.path,
      refreshListenable: _auth,
      routes: [
        GoRoute(
          name: Screen.login.name,
          path: Screen.login.path,
          redirect: (context, state) async {
            // Auth state is updated in main before the corresponding widget is built.
            final signedIn = _auth.signedIn ?? false;
            // If user is already signed in, redirect to dashboard
            if (signedIn) {
              return Screen.dashboard.location;
            }

            return null;
          },
          builder: (context, state) => LoginScreen(
            onLogin: (user) {
              _auth.login(user).then((signedIn) {
                if (signedIn) {
                  CustomerIO.identify(identifier: user.email, attributes: {
                    "first_name": user.displayName,
                    "email": user.email,
                    "is_guest": user.isGuest,
                  });
                }
                return signedIn;
              });
            },
          ),
        ),
        GoRoute(
          name: Screen.dashboard.name,
          path: Screen.dashboard.path,
          redirect: (context, state) async {
            // Auth state is updated in main before the corresponding widget is built.
            final signedIn = _auth.signedIn ?? false;
            // If user is not signed in and public view is not allowed, redirect
            // to login screen
            final isPublicViewAllowed =
                state.location.toAppScreen()?.isPublicViewAllowed == true;
            if (!signedIn && !isPublicViewAllowed) {
              return Screen.login.location;
            }

            return null;
          },
          builder: (context, state) => DashboardScreen(auth: _auth),
          routes: [
            GoRoute(
              name: Screen.dashboardRedirect.name,
              path: Screen.dashboardRedirect.path,
              // Redirect to dashboard directly
              redirect: (context, state) => Screen.dashboard.path,
            ),
            GoRoute(
              name: Screen.settings.name,
              path: Screen.settings.path,
              builder: (context, state) => SettingsScreen(
                auth: _auth,
                siteIdInitialValue: state.queryParameters['site_id'],
                apiKeyInitialValue: state.queryParameters['api_key'],
              ),
            ),
            GoRoute(
              name: Screen.customEvents.name,
              path: Screen.customEvents.path,
              builder: (context, state) => const CustomEventScreen(),
            ),
            GoRoute(
              name: Screen.deviceAttributes.name,
              path: Screen.deviceAttributes.path,
              builder: (context, state) => AttributesScreen.device(),
            ),
            GoRoute(
              name: Screen.profileAttributes.name,
              path: Screen.profileAttributes.path,
              builder: (context, state) => AttributesScreen.profile(),
            ),
          ],
        ),
      ],
    );

    // Listen for user login state and display the sign in screen when logged out.
    _auth.addListener(_handleAuthStateChanged);
    // Initialize Customer.io SDK once when app modules are initialized.
    _initCustomerIO().then((value) {
      // Initial route will not be tracked if user is logged in as there is no
      // route change, tracking initial screen manually for this case.
      // Events/screens can only be tracked after SDK has been initialized.
      if (_router.location.toAppScreen() != Screen.dashboard) {
        _onRouteChanged();
      }
      return value;
    });
    _customerIOSDK.addListener(_handleSDKConfigurationsChanged);

    // Listen to screen changes for observing screens
    _router.addListener(() => _onRouteChanged());

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerIOSDKScope(
      notifier: _customerIOSDK,
      child: AmiAppAuthScope(
        notifier: _auth,
        child: MaterialApp.router(
          routerConfig: _router,
          themeMode: ThemeMode.system,
          theme: _createTheme(false),
          darkTheme: _createTheme(true),
        ),
      ),
    );
  }

  ThemeData _createTheme(bool isDark) {
    final ThemeData theme;
    final ColorScheme colorScheme;
    final SystemUiOverlayStyle systemOverlayStyle;
    if (isDark) {
      theme = ThemeData.dark();
      colorScheme = darkColorScheme;
      systemOverlayStyle = SystemUiOverlayStyle.light;
    } else {
      theme = ThemeData.light();
      colorScheme = lightColorScheme;
      systemOverlayStyle = SystemUiOverlayStyle.dark;
    }

    return theme.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: theme.appBarTheme.copyWith(
        systemOverlayStyle: systemOverlayStyle,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
          ),
        ),
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      extensions: _themeExtensions,
    );
  }

  void _onRouteChanged() {
    if (_customerIOSDK.sdkConfig?.screenTrackingEnabled == true) {
      final Screen? screen = _router.location.toAppScreen();
      if (screen != null) {
        CustomerIO.screen(name: screen.name);
      }
    }
  }

  void _handleAuthStateChanged() {
    if (_auth.signedIn == false) {
      CustomerIO.clearIdentify();
      _auth.clearUserState();
    }
  }

  void _handleSDKConfigurationsChanged() {
    _initCustomerIO();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthStateChanged);
    _customerIOSDK.removeListener(_handleSDKConfigurationsChanged);

    _auth.dispose();
    _customerIOSDK.dispose();
    _router.dispose();

    super.dispose();
  }
}
