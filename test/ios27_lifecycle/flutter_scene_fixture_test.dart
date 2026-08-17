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
    });

    test(
      '$sample keeps legacy default and provides explicit UIScene fixture',
      () {
        final legacy = read('$runner/Info.plist');
        final scene = read('$runner/Info-Scene.plist');
        final sceneDelegate = read('$runner/SceneDelegate.swift');
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

  test('Xcode 27 preview compiles both host topologies', () {
    final workflow = read('.github/workflows/ios-toolchain-compatibility.yml');

    expect(workflow, contains('build_arguments=('));
    expect(
      workflow,
      contains('CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene'),
    );
    expect(workflow, contains('-workspace ios/Runner.xcworkspace'));
    expect(workflow, contains('-project ios/Runner.xcodeproj'));
    expect(
      workflow,
      contains('**Host topologies:** legacy AppDelegate and UIScene'),
    );
  });
}
