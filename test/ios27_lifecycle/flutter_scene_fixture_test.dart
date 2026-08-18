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
  // These source-level checks are structural tripwires. Runtime delivery remains
  // covered separately by the hosted simulator workflow and MBL-2233 device evidence.
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
        isNot(contains('registerLiveActivitySceneHandlerIfNeeded(with: self)')),
      );
      expect(
        source,
        contains('guard !registry.hasPlugin(Self.liveActivityScenePluginKey)'),
      );
      expect(
        source,
        contains('private var liveActivitySceneHandlerRegistered = false'),
      );
      expect(source,
          contains('registrar.addSceneDelegate(liveActivitySceneHandler)'));
      expect(
        source,
        contains('liveActivitySceneHandler.flutterEngineDidBecomeReady()'),
      );
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
      final launchForward = source.indexOf('return super.application', launch);
      expect(launchRegistration, greaterThan(launch));
      expect(launchForward, greaterThan(launchRegistration));

      final implicitCallback = source.indexOf(
        'func didInitializeImplicitFlutterEngine',
      );
      final sceneRegistration = source.indexOf(
        'registerLiveActivitySceneHandlerIfNeeded(with: engineBridge.pluginRegistry)',
        implicitCallback,
      );
      final generatedRegistration = source.indexOf(
        'registerPluginsIfNeeded(with: engineBridge.pluginRegistry)',
        implicitCallback,
      );
      expect(sceneRegistration, greaterThan(implicitCallback));
      expect(generatedRegistration, greaterThan(sceneRegistration));
    });

    test(
      '$sample keeps legacy default and provides explicit UIScene fixture',
      () {
        final legacy = read('$runner/Info.plist');
        final scene = read('$runner/Info-Scene.plist');
        final traceSceneDelegate =
            read('$runner/LifecycleTraceSceneDelegate.swift');
        final sceneHandler = read('$runner/SceneDelegate.swift');
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
        expect(
          scene,
          contains(r'$(PRODUCT_MODULE_NAME).LifecycleTraceSceneDelegate'),
        );
        expect(scene, contains('<string>fetch</string>'));
        expect(scene, contains('<string>remote-notification</string>'));
        expect(
          traceSceneDelegate,
          contains('final class LifecycleTraceSceneDelegate: FlutterSceneDelegate'),
        );
        expect(sceneHandler, contains('FlutterSceneLifeCycleDelegate'));
        expect(
          sceneHandler,
          contains('willConnectTo session: UISceneSession'),
        );
        expect(
          sceneHandler,
          contains('openURLContexts urlContexts: Set<UIOpenURLContext>'),
        );
        expect(
          sceneHandler,
          contains(
              'handleWidgetURL = CustomerIOLiveActivities.handleWidgetUrl'),
        );
        expect(
          sceneHandler,
          contains('guard !isCustomerIOURL(routableURL)'),
        );
        expect(
          sceneHandler,
          contains('customerio-flutter-scene-will-connect'),
        );
        expect(
          sceneHandler,
          contains('customerio-flutter-scene-open-url-contexts'),
        );
        expect(
          sceneHandler,
          contains('UIApplication.shared.delegate?.application?('),
        );
        expect(
          sceneHandler,
          contains('connectionOptions?.userActivities.isEmpty ?? true'),
        );
        expect(sceneHandler, contains('sceneDidBecomeActive'));
        expect(sceneHandler, contains('sceneWillResignActive'));
        expect(sceneHandler, contains('pendingForwardingURLs'));
        expect(sceneHandler, contains('maximumQueuedForwardingAttempts'));
        expect(
          sceneHandler,
          contains('maximumQueuedForwardingAttempts = 40'),
        );
        expect(sceneHandler, contains('schedulePendingURLDrain'));
        expect(sceneHandler, contains('guard flutterEngineIsReady else'));
        expect(sceneHandler, contains('flutterEngineDidBecomeReady()'));
        expect(sceneHandler, contains('readinessWaitedForEngine'));
        expect(sceneHandler, contains('readinessScheduledDrain'));
        expect(
          sceneHandler,
          contains(
            'Flutter URL forwarding retry budget exhausted; URLs remain queued for the next activation',
          ),
        );
        expect(
          sceneHandler,
          contains(
            'Deferred pending Flutter URLs until the next scene activation',
          ),
        );
        expect(
          sceneHandler,
          contains('sceneIsActive: sceneIsActive'),
        );
        expect(
          sceneHandler,
          contains('if sceneIsActive, forwardToFlutter(routableURL)'),
        );
        expect(sceneHandler, contains('urlsToRetry'));
        expect(sceneHandler, contains('&& nestedHandled'));
        expect(
          sceneHandler,
          contains('NSSelectorFromString("sceneDidBecomeActive:")'),
        );
        expect(
          sceneHandler,
          contains('return consumedTrackingURL'),
        );
        expect(sceneHandler, contains('routedURLs.count == 2'));
        expect(sceneHandler, contains('webRoutes.count == 2'));
        expect(sceneHandler, contains('&& rejectedRouteConsumed'));
        expect(sceneHandler, contains('&& noRedirectConsumed'));
        expect(sceneHandler, contains('&& !ordinaryHandled'));
        expect(sceneHandler, contains('&& ordinaryRoutes.isEmpty'));
        expect(
          sceneHandler,
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
        expect(
          projectSource,
          contains('LifecycleTraceSceneDelegate.swift in Sources'),
        );
        if (sample == 'spm') {
          expect(
            projectSource,
            contains('LiveActivities_Attributes in Frameworks'),
          );
        }
        expect(
          projectSource,
          contains(
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG \$(inherited) \$(CIO_SCENE_CONTRACT_CONDITIONS)";',
          ),
        );
      },
    );
  }

  test('sample apps share the same scene delegate implementation', () {
    expect(
      read('apps/flutter_sample_spm/ios/Runner/SceneDelegate.swift'),
      read('apps/flutter_sample_cocoapods/ios/Runner/SceneDelegate.swift'),
    );
  });

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
      contains(
        'Verify Flutter scene forwarding and source-level URL-handler contract',
      ),
    );
    expect(workflow, contains('customerio-flutter-scene-will-connect'));
    expect(workflow, contains('customerio-flutter-scene-did-become-active'));
    expect(workflow, isNot(contains('xcrun simctl openurl')));
    expect(
      workflow,
      contains(
        'CIO_SCENE_CONTRACT_CONDITIONS=CIO_SCENE_CONTRACT_SELF_TEST',
      ),
    );
    expect(
      workflow,
      contains('customerio-flutter-scene-handler-contract-passed'),
    );
    expect(workflow, contains('CIO_SCENE_HANDLER_RUN_TOKEN'));
    expect(workflow, contains('GITHUB_RUN_ID'));
    expect(
      occurrences(workflow, 'ios/launch-simulator-app/v1@'),
      2,
    );
    // This exact pin is an intentional tripwire until customerio/mobile-ci-tools#16 merges.
    expect(
      occurrences(
        workflow,
        'launch-simulator-app/v1@973084092fbe9a46b35aa8876137dca5bfde6c40',
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
        '**Host topologies:** AppDelegate-only compile plus expected Xcode 27 launch rejection; UIScene compile, launch survival, cold connection, and source-level URL-handler contract',
      ),
    );
  });
}
