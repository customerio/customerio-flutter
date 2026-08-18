import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final Directory root = _repoRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  const String pluginPath =
      'ios/customer_io/Sources/customer_io/CustomerIOPlugin.swift';
  const String lifecyclePath =
      'ios/customer_io/Sources/customer_io/Lifecycle/CustomerIOFlutterLifecycle.swift';
  const String liveActivitiesPath =
      'ios/customer_io/Sources/customer_io/LiveActivities/CustomerIOLiveActivities.swift';

  test('plugin registers only the lifecycle seat selected by scene manifest',
      () {
    final String plugin = read(pluginPath);
    final String lifecycle = read(lifecyclePath);

    expectInOrder(plugin, <String>[
      'guard instance.lifecycleHandler.shouldRegisterApplicationDelegate',
      'lifecycleRegistrationLock.lock()',
      'registrar.addApplicationDelegate(instance)',
    ]);
    expectInOrder(plugin, <String>[
      'guard instance.lifecycleHandler.shouldRegisterSceneDelegate',
      'NSSelectorFromString("addSceneDelegate:")',
      'registrar.perform(selector, with: instance.lifecycleHandler)',
    ]);
    expect(plugin, contains('reportUnavailableSceneRegistration()'));
    expect(
      'registrar.addApplicationDelegate(instance)'.allMatches(plugin),
      hasLength(1),
    );
    expect(lifecycle, contains('sceneManifestInfoPlistKey'));
    expect(lifecycle, contains('private let usesUIScene: Bool'));
    expect(lifecycle, contains('!usesUIScene'));
    expect(
      lifecycle,
      contains(
          'extension CustomerIOPlugin: FlutterApplicationLifeCycleDelegate'),
    );
    expect(lifecycle, contains('@objc(scene:willConnectToSession:options:)'));
    expect(lifecycle, contains('@objc(scene:openURLContexts:)'));
  });

  test('both topologies use the released native URL primitive', () {
    final String lifecycle = read(lifecyclePath);

    expectInOrder(lifecycle, <String>[
      'func handleApplicationOpenURL(',
      'guard !usesUIScene else { return false }',
      'return routeURL(url, applicationOptions: options)',
    ]);
    expectInOrder(lifecycle, <String>[
      'func handleSceneConnection(',
      'guard usesUIScene',
      'return routeURL(',
    ]);
    expectInOrder(lifecycle, <String>[
      'func handleSceneOpenURLContexts(',
      'guard usesUIScene',
      'return routeURL(',
    ]);
    expect(lifecycle, isNot(contains('CioSceneLifecycleCoordinator')));
    expect(lifecycle, isNot(contains('CioSceneLifecycleHandlingResult')));
    expect(lifecycle, isNot(contains('CustomerIOAppLifecycleHostTopology')));
    expect(lifecycle, isNot(contains('HostTopology')));
    expect(lifecycle, isNot(contains('preconditionFailure(')));
  });

  test('one UIKit scene occurrence is routed once across Flutter engines', () {
    final String lifecycle = read(lifecyclePath);

    for (final String expected in <String>[
      'weak var occurrence: AnyObject?',
      'ObjectIdentifier(occurrence)',
      'return existing.handled',
      'result.handled = route()',
      'guard urlContexts.count == 1',
      'guard connectionOptions.urlContexts.count == 1',
      'connectionOptions.userActivities.isEmpty',
      'connectionOptions.shortcutItem == nil',
    ]) {
      expect(lifecycle, contains(expected));
    }
    expect(lifecycle, isNot(contains('for urlContext in urlContexts {')));
  });

  test('nested tracking redirects are rejected before host forwarding', () {
    final String lifecycle = read(lifecyclePath);
    final String liveActivities = read(liveActivitiesPath);

    expect(liveActivities, contains('CioLiveActivityWidgetUrl.parse(url)'));
    expectInOrder(lifecycle, <String>[
      'CustomerIOLiveActivities.handleWidgetUrl(url)',
      'CustomerIOLiveActivities.isWidgetTrackingURL(destination)',
      'appDelegate.application?(',
      'UIApplication.shared.open(destination, options: [:])',
    ]);
    expect(
      lifecycle,
      contains(
          'guard !isForwardingRedirectToApplication else { return false }'),
    );
    expect(
      lifecycle,
      contains('defer { isForwardingRedirectToApplication = false }'),
    );
  });

  test('adapter does not own push, shortcut, or user-activity completion', () {
    final String lifecycle = read(lifecyclePath);

    for (final String forbidden in <String>[
      'UNUserNotificationCenter',
      'didRegisterForRemoteNotifications',
      'didReceiveRemoteNotification',
      'completionHandler:',
      'handleApplicationShortcut(',
      'handleSceneShortcut(',
      'handleApplicationUserActivity(',
      'handleSceneUserActivity(',
    ]) {
      expect(lifecycle, isNot(contains(forbidden)));
    }
  });

  test('samples select one topology and leave URL routing to the plugin', () {
    for (final String sample in <String>['spm', 'cocoapods']) {
      final String prefix = 'apps/flutter_sample_$sample/ios/Runner';
      final String legacy = read('$prefix/Info.plist');
      final String scene = read('$prefix/Info-Scene.plist');
      final String appDelegate = read('$prefix/AppDelegate.swift');
      final String sceneDelegate = read('$prefix/SceneDelegate.swift');

      expect(legacy, isNot(contains('UIApplicationSceneManifest')));
      expect(scene, contains('UIApplicationSceneManifest'));
      expect(legacy, isNot(contains('CustomerIOAppLifecycleHostTopology')));
      expect(scene, isNot(contains('CustomerIOAppLifecycleHostTopology')));
      expect(
        appDelegate,
        isNot(contains('CustomerIOLiveActivities.handleWidgetUrl')),
      );
      expect(sceneDelegate, contains('FlutterSceneDelegate'));
      expect(
        sceneDelegate,
        isNot(contains('CustomerIOLiveActivities.handleWidgetUrl')),
      );
    }
  });
}

void expectInOrder(String source, List<String> values) {
  var cursor = -1;
  for (final String value in values) {
    final int next = source.indexOf(value, cursor + 1);
    expect(next, greaterThan(cursor),
        reason: 'missing or out of order: $value');
    cursor = next;
  }
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
