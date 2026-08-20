import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final Directory root = _repoRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  const String pluginPath =
      'ios/customer_io/Sources/customer_io/CustomerIOPlugin.swift';
  const String lifecyclePath =
      'ios/customer_io/Sources/customer_io/Lifecycle/CustomerIOFlutterLifecycle.swift';
  const String deepLinkRouterPath =
      'ios/customer_io/Sources/customer_io/Lifecycle/CustomerIOFlutterDeepLinkRouter.swift';

  test('plugin registers scene routing only for a UIScene host', () {
    final String plugin = read(pluginPath);
    final String lifecycle = read(lifecyclePath);

    for (final String expected in <String>[
      'registrar.publish(instance)',
      'guard instance.lifecycleHandler.shouldRegisterSceneDelegate',
      'NSSelectorFromString("addSceneDelegate:")',
      'registrar.perform(selector, with: instance.lifecycleHandler)',
    ]) {
      expect(plugin, contains(expected));
    }
    for (final String expected in <String>[
      'sceneManifestInfoPlistKey = "UIApplicationSceneManifest"',
      'forInfoDictionaryKey: "FlutterDeepLinkingEnabled"',
      'CustomerIOLifecycleSeatSelection.shouldRegisterSceneDelegate(',
      '@objc(scene:willConnectToSession:options:)',
      '@objc(scene:openURLContexts:)',
      '@MainActor',
      'attributeUnambiguousTrackingURL(in: connectionOptions.urlContexts)',
      'attributeUnambiguousTrackingURL(in: urlContexts)',
      'claimRedirectDelivery(for: occurrence)',
    ]) {
      expect(lifecycle, contains(expected));
    }
    expect(plugin, isNot(contains('registrar.addApplicationDelegate')));
  });

  test('adapter owns only Customer.io URL routing', () {
    final String lifecycle = read(lifecyclePath);
    final String router = read(deepLinkRouterPath);

    for (final String expected in <String>[
      'CustomerIOLiveActivities.handleWidgetUrl',
      'hasNotificationResponse: connectionOptions.notificationResponse != nil',
      'viewController.engine.navigationChannel.invokeMethod(',
      'NSSelectorFromString("viewController")',
      'readyViewController(in: scene)',
      'sceneFlutterViewControllers(in: scene)',
      'retryOrReportUnavailable(url, in: scene, remainingAttempts: remainingAttempts)',
      'deepLinkRouter.route(destination, in: scene)',
    ]) {
      expect('$lifecycle\n$router', contains(expected));
    }
    for (final String forbidden in <String>[
      'UNUserNotificationCenter',
      'didRegisterForRemoteNotifications',
      'didReceiveRemoteNotification',
      'handleSceneShortcut(',
      'handleSceneUserActivity(',
      'scene.open(',
      'UIApplication.shared.open(',
      'appDelegate.application?(',
    ]) {
      expect('$lifecycle\n$router', isNot(contains(forbidden)));
    }
  });

  test('samples select one topology and do not duplicate URL routing', () {
    for (final String sample in <String>['spm', 'cocoapods']) {
      final String prefix = 'apps/flutter_sample_$sample/ios/Runner';
      final String legacy = read('$prefix/Info.plist');
      final String scene = read('$prefix/Info-Scene.plist');
      final String appDelegate = read('$prefix/AppDelegate.swift');
      final String sceneDelegate = read('$prefix/SceneDelegate.swift');

      expect(legacy, isNot(contains('UIApplicationSceneManifest')));
      expect(scene, contains('UIApplicationSceneManifest'));
      expect(sceneDelegate, contains('FlutterSceneDelegate'));
      expect(appDelegate, contains('CustomerIOLiveActivities.handleWidgetUrl'));
      expect(
        appDelegate,
        contains('forInfoDictionaryKey: "UIApplicationSceneManifest"'),
      );
      expect(
        sceneDelegate,
        isNot(contains('CustomerIOLiveActivities.handleWidgetUrl')),
      );
    }
  });
}

Directory _repoRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/apps').existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('could not locate repository root');
    }
    dir = dir.parent;
  }
  return dir;
}
