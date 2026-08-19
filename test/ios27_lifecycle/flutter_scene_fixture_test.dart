import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> samples = <String>['spm', 'cocoapods'];

String read(String path) {
  final File file = File('${Directory.current.path}/$path');
  expect(file.existsSync(), isTrue, reason: 'missing fixture: ${file.path}');
  return file.readAsStringSync();
}

int occurrences(String source, String value) => value.allMatches(source).length;

void main() {
  for (final String sample in samples) {
    final String runner = 'apps/flutter_sample_$sample/ios/Runner';
    final String project =
        'apps/flutter_sample_$sample/ios/Runner.xcodeproj/project.pbxproj';

    test('$sample registers generated plugins once per Flutter engine', () {
      final String source = read('$runner/AppDelegate.swift');

      expect(source, contains('FlutterImplicitEngineDelegate'));
      expect(
        occurrences(
          source,
          'GeneratedPluginRegistrant.register(with: registry)',
        ),
        1,
      );
      expect(
        occurrences(
          source,
          'permissionHandler.register(with: registrar.messenger())',
        ),
        1,
      );
      expect(
        source,
        contains('guard !registry.hasPlugin(Self.permissionChannelPluginKey)'),
      );
      expect(
        source,
        contains('registerPluginsIfNeeded(with: engineBridge.pluginRegistry)'),
      );
      expect(source, contains('registerPluginsIfNeeded(with: self)'));
      expect(source, isNot(contains('rootViewController')));
      expect(
        source,
        isNot(contains('registerLiveActivitySceneHandlerIfNeeded')),
      );

      final int launch = source.indexOf('didFinishLaunchingWithOptions');
      final int launchRegistration = source.indexOf(
        'registerPluginsIfNeeded(with: self)',
        launch,
      );
      final int launchForward =
          source.indexOf('return super.application', launch);
      expect(launchRegistration, greaterThan(launch));
      expect(launchForward, greaterThan(launchRegistration));
    });

    test('$sample provides legacy and UIScene host topologies', () {
      final String legacy = read('$runner/Info.plist');
      final String scene = read('$runner/Info-Scene.plist');
      final String sceneDelegate = read('$runner/SceneDelegate.swift');
      final String projectSource = read(project);

      expect(legacy, isNot(contains('UIApplicationSceneManifest')));
      expect(scene, contains('UIApplicationSceneManifest'));
      expect(scene, contains(r'$(PRODUCT_MODULE_NAME).SceneDelegate'));
      expect(scene, contains('<string>fetch</string>'));
      expect(scene, contains('<string>remote-notification</string>'));

      expect(
        sceneDelegate,
        contains('final class SceneDelegate: FlutterSceneDelegate'),
      );
      expect(
        sceneDelegate,
        contains('willConnectTo session: UISceneSession'),
      );
      expect(sceneDelegate, contains('sceneDidBecomeActive'));
      expect(
        sceneDelegate,
        contains('customerio-flutter-scene-will-connect'),
      );
      expect(
        sceneDelegate,
        contains('customerio-flutter-scene-did-become-active'),
      );
      expect(
        sceneDelegate,
        isNot(contains('CustomerIOLiveActivities.handleWidgetUrl')),
      );
      expect(
        sceneDelegate,
        isNot(contains('FlutterSceneLifeCycleDelegate')),
      );

      expect(
        occurrences(
          projectSource,
          r'INFOPLIST_FILE = "Runner/Info$(CIO_LIFECYCLE_INFOPLIST_SUFFIX).plist";',
        ),
        3,
      );
      expect(
        occurrences(projectSource, 'CIO_LIFECYCLE_INFOPLIST_SUFFIX = "";'),
        3,
      );
      expect(projectSource, contains('Info-Scene.plist'));
      expect(projectSource, contains('SceneDelegate.swift in Sources'));
      expect(projectSource, isNot(contains('CIO_SCENE_CONTRACT_CONDITIONS')));
    });
  }

  test('sample apps share the same standard scene delegate', () {
    expect(
      read('apps/flutter_sample_spm/ios/Runner/SceneDelegate.swift'),
      read('apps/flutter_sample_cocoapods/ios/Runner/SceneDelegate.swift'),
    );
  });

  test('Xcode 27 proves legacy rejection and UIScene launch callbacks', () {
    final String workflow =
        read('.github/workflows/ios-toolchain-compatibility.yml');

    expect(workflow, contains('build_arguments=('));
    expect(workflow, contains('CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene'));
    expect(
      workflow,
      contains(
        'Confirm the AppDelegate-only control reproduces the Xcode 27 launch failure',
      ),
    );
    expect(
      workflow,
      contains(
        'UIScene life cycle is required|_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption',
      ),
    );
    expect(workflow, contains('Launch the UIScene fixture'));
    expect(workflow, contains('Verify Flutter scene callbacks'));
    expect(workflow, contains('customerio-flutter-scene-will-connect'));
    expect(workflow, contains('customerio-flutter-scene-did-become-active'));
    expect(workflow, isNot(contains('CIO_SCENE_CONTRACT_SELF_TEST')));
    expect(workflow, isNot(contains('scene-handler-contract-passed')));
    expect(workflow, contains('CIO_SCENE_HANDLER_RUN_TOKEN'));
    expect(workflow, contains('GITHUB_RUN_ID'));
    expect(
      occurrences(workflow, 'ios/launch-simulator-app/v1@main'),
      2,
    );
    expect(occurrences(workflow, "expected-ios-major: '27'"), 2);
    expect(occurrences(workflow, "survival-seconds: '10'"), 2);
    expect(workflow, contains('continue-on-error: true'));
    expect(workflow, contains("test \"\$LAUNCH_OUTCOME\" = 'failure'"));
  });
}
