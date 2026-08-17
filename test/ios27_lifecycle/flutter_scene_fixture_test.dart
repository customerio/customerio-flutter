import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const samples = ['spm', 'cocoapods'];

String read(String path) {
  final file = File('${Directory.current.path}/$path');
  expect(file.existsSync(), isTrue, reason: 'missing fixture: ${file.path}');
  return file.readAsStringSync();
}

int occurrences(String source, String value) => value.allMatches(source).length;

void main() {
  for (final sample in samples) {
    final runner = 'apps/flutter_sample_$sample/ios/Runner';
    final project =
        'apps/flutter_sample_$sample/ios/Runner.xcodeproj/project.pbxproj';

    test('$sample registers launch and implicit engines exactly once', () {
      final source = read('$runner/AppDelegate.swift');

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
      expect(
        source,
        contains(
          'registerLiveActivitySceneHandlerIfNeeded(with: engineBridge.pluginRegistry)',
        ),
      );
      expect(
        source,
        contains('registerLiveActivitySceneHandlerIfNeeded(with: self)'),
      );
      expect(source,
          contains('registrar.addSceneDelegate(liveActivitySceneHandler)'));
      expect(source, contains('registerPluginsIfNeeded(with: self)'));
      expect(source, isNot(contains('rootViewController')));

      final helper = source.indexOf(
        'private func registerPluginsIfNeeded(with registry: FlutterPluginRegistry)',
      );
      final claim = source.indexOf('registry.registrar(forPlugin:', helper);
      final generated = source.indexOf(
        'GeneratedPluginRegistrant.register(with: registry)',
        helper,
      );
      final permission = source.indexOf(
        'permissionHandler.register(with: registrar.messenger())',
        helper,
      );
      expect(helper, greaterThanOrEqualTo(0));
      expect(claim, greaterThan(helper));
      expect(generated, greaterThan(claim));
      expect(permission, greaterThan(generated));

      final launch = source.indexOf('didFinishLaunchingWithOptions');
      final launchRegistration = source.indexOf(
        'registerPluginsIfNeeded(with: self)',
        launch,
      );
      final sceneHandlerRegistration = source.indexOf(
        'registerLiveActivitySceneHandlerIfNeeded(with: self)',
        launch,
      );
      final launchForward = source.indexOf('return super.application', launch);
      expect(sceneHandlerRegistration, greaterThan(launch));
      expect(launchRegistration, greaterThan(sceneHandlerRegistration));
      expect(launchRegistration, greaterThan(launch));
      expect(launchForward, greaterThan(launchRegistration));
    });

    test(
      '$sample keeps legacy default and provides explicit UIScene fixture',
      () {
        final legacy = read('$runner/Info.plist');
        final scene = read('$runner/Info-Scene.plist');
        final sceneDelegate = read('$runner/SceneDelegate.swift');
        final appDelegate = read('$runner/AppDelegate.swift');
        final projectSource = read(project);

        final sceneWithoutManifest = scene.replaceFirst(
          RegExp(
            r'\t<key>UIApplicationSceneManifest</key>\n.*?(?=\t<key>UIApplicationSupportsIndirectInputEvents</key>)',
            dotAll: true,
          ),
          '',
        );

        expect(legacy, isNot(contains('UIApplicationSceneManifest')));
        expect(scene, contains('UIApplicationSceneManifest'));
        expect(sceneWithoutManifest, legacy);
        expect(scene, contains(r'$(PRODUCT_MODULE_NAME).SceneDelegate'));
        expect(scene, contains('<string>fetch</string>'));
        expect(scene, contains('<string>remote-notification</string>'));
        expect(
          sceneDelegate,
          contains('class SceneDelegate: FlutterSceneDelegate'),
        );
        expect(sceneDelegate, contains('FlutterSceneLifeCycleDelegate'));
        expect(
          sceneDelegate,
          contains('willConnectTo session: UISceneSession'),
        );
        expect(
          sceneDelegate,
          contains('openURLContexts URLContexts: Set<UIOpenURLContext>'),
        );
        expect(
          sceneDelegate,
          contains(
              'handleWidgetURL = CustomerIOLiveActivities.handleWidgetUrl'),
        );
        expect(
          sceneDelegate,
          contains('guard !isCustomerIOURL(routableURL)'),
        );
        expect(
          sceneDelegate,
          contains('customerio-flutter-scene-will-connect'),
        );
        expect(
          sceneDelegate,
          contains('customerio-flutter-scene-open-url-contexts'),
        );
        expect(
          sceneDelegate,
          contains('UIApplication.shared.delegate?.application?('),
        );
        expect(
          sceneDelegate,
          contains('connectionOptions?.userActivities.isEmpty ?? true'),
        );
        expect(sceneDelegate, contains('sceneDidBecomeActive'));
        expect(sceneDelegate, contains('pendingColdStartURLs'));
        expect(sceneDelegate, contains('&& !nestedHandled'));
        expect(sceneDelegate, contains('routedURLs.count == 2'));
        expect(sceneDelegate, contains('webRoutes.count == 2'));
        expect(
          sceneDelegate,
          contains('#if CIO_SCENE_CONTRACT_SELF_TEST'),
        );
        expect(
          appDelegate,
          contains(
            '#if CIO_SCENE_CONTRACT_SELF_TEST\n        if ProcessInfo.processInfo.environment["CIO_SCENE_HANDLER_SELF_TEST"]',
          ),
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
      },
    );
  }

  test('Xcode 27 preview proves the legacy failure and UIScene launch', () {
    final workflow = read('.github/workflows/ios-toolchain-compatibility.yml');

    expect(workflow, contains('uses: ruby/setup-ruby@'));
    expect(workflow, contains('# v1.321.0'));
    expect(workflow, contains("ruby-version: '3.4'"));
    expect(workflow, contains('build_arguments=('));
    expect(
      workflow,
      contains('CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene'),
    );
    expect(workflow, contains('-workspace ios/Runner.xcworkspace'));
    expect(workflow, contains('-project ios/Runner.xcodeproj'));
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
    expect(
      workflow,
      contains('Verify Flutter scene forwarding and URL-handler contract'),
    );
    expect(workflow, contains('customerio-flutter-scene-will-connect'));
    expect(workflow, isNot(contains('xcrun simctl openurl')));
    expect(
      workflow,
      contains(
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS=CIO_SCENE_CONTRACT_SELF_TEST',
      ),
    );
    expect(
      workflow,
      contains('customerio-flutter-scene-handler-contract-passed'),
    );
    expect(
      occurrences(workflow, 'ios/launch-simulator-app/v1@'),
      2,
    );
    // This exact pin is an intentional tripwire until customerio/mobile-ci-tools#16 merges.
    expect(
      occurrences(
        workflow,
        'launch-simulator-app/v1@f178d035fd2d76c35abcf0561abca473c13e2084',
      ),
      2,
    );
    expect(occurrences(workflow, "expected-ios-major: '27'"), 2);
    expect(occurrences(workflow, "survival-seconds: '10'"), 2);
    expect(workflow, contains('continue-on-error: true'));
    expect(workflow, contains("test \"\$LAUNCH_OUTCOME\" = 'failure'"));
    expect(
      workflow,
      contains(
        r'${{ matrix.app }}-scene-xcode-27/Build/Products/Debug-iphonesimulator/Runner.app',
      ),
    );
    expect(
      workflow,
      contains(
        '**Host topologies:** AppDelegate-only compile plus expected Xcode 27 launch rejection; UIScene compile, launch survival, cold connection, and URL-handler contract',
      ),
    );
  });
}
