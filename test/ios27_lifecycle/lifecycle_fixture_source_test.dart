import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// L0/L1 fixture-shape checks. Runtime ordering and evidence-level claims come
/// only from canonical capture validation, never from these source assertions.
void main() {
  final Directory repoRoot = _repoRoot();
  const List<String> samples = <String>['spm', 'cocoapods'];

  String appDir(String sample) => 'apps/flutter_sample_$sample';

  String read(String relativePath) {
    final File file = File('${repoRoot.path}/$relativePath');
    expect(file.existsSync(), isTrue, reason: 'missing $relativePath');
    return file.readAsStringSync();
  }

  group('real implicit-engine consumer seat', () {
    for (final String sample in samples) {
      test('$sample registers plugins once on engineBridge registry', () {
        final String source =
            read('${appDir(sample)}/ios/Runner/AppDelegate.swift');
        final String body =
            _bodyOf(source, 'didInitializeImplicitFlutterEngine');
        expect(
          source,
          contains('FlutterAppDelegate, FlutterImplicitEngineDelegate'),
        );
        expect(
          source,
          contains(
            'didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge)',
          ),
        );
        expect(body, contains('let registry = engineBridge.pluginRegistry'));
        expect(body, contains('guard !registry.hasPlugin('));
        expect(
          body,
          contains('GeneratedPluginRegistrant.register(with: registry)'),
        );
        expect(
          body,
          contains('permissionHandler.register(with: registrar.messenger())'),
        );
        expect(
          'GeneratedPluginRegistrant.register('.allMatches(source).length,
          1,
        );
        expect('permissionHandler.register('.allMatches(source).length, 1);
        expect(
          _bodyOf(source, 'didFinishLaunchingWithOptions'),
          isNot(contains('GeneratedPluginRegistrant.register(')),
        );
      });
    }
  });

  group('honest callback seats', () {
    for (final String sample in samples) {
      test('$sample observes raw marker and rejects spoofed identity', () {
        final String fixture = read(
          '${appDir(sample)}/ios/Runner/LifecycleTraceFlutterFixture.swift',
        );
        final String decoder = read(
          '${appDir(sample)}/ios/Runner/LifecycleTraceRawLaunchMarker.swift',
        );
        expect(fixture, contains('object: center'));
        expect(
          fixture,
          contains('LifecycleTraceRawLaunchMarker.decode('),
        );
        expect(
          decoder,
          contains('notification.object as AnyObject? === center'),
        );
        expect(
          decoder,
          contains('processInstanceID == expectedProcessInstanceID'),
        );
        expect(
          'callback: .applicationDidFinishLaunching'.allMatches(fixture).length,
          1,
        );
      });

      test('$sample adds no lifecycle selector or completion ownership', () {
        final String appDelegate =
            read('${appDir(sample)}/ios/Runner/AppDelegate.swift');
        final String fixture = read(
          '${appDir(sample)}/ios/Runner/LifecycleTraceFlutterFixture.swift',
        );
        expect(
          appDelegate,
          isNot(matches(RegExp(r'override func application\([^)]*willFinish'))),
        );
        expect(
          appDelegate,
          isNot(matches(RegExp(r'override func applicationDidBecomeActive'))),
        );
        expect(fixture, isNot(contains('completionHandler')));
        expect(fixture, contains('UIApplication.didBecomeActiveNotification'));
      });

      test('$sample scene subclass only observes inherited willConnect', () {
        final String source = read(
          '${appDir(sample)}/ios/Runner/LifecycleTraceSceneDelegate.swift',
        );
        expect(
          source,
          contains(
            'final class LifecycleTraceSceneDelegate: FlutterSceneDelegate',
          ),
        );
        expect('override func scene('.allMatches(source).length, 1);
        expect(source, contains('callback: .sceneWillConnect'));
        expect(
          source,
          contains('callback: .flutterSceneWillConnectForwarded'),
        );
        expect(source, contains('super.scene(scene, willConnectTo: session'));
        expect(
          'LifecycleTraceEvidence.observe(scene: scene, callback: .sceneWillConnect)'
              .allMatches(source)
              .length,
          1,
        );
        expect(
          'LifecycleTraceEvidence.observe(connectedScenes:'
              .allMatches(source)
              .length,
          1,
        );
        expect(
          'LifecycleTraceEvidence.observe(connectionOptions:'
              .allMatches(source)
              .length,
          1,
        );
        expect(source, isNot(contains('observe(sceneSession:')));
      });
    }
  });

  group('immutable legacy and scene builds', () {
    for (final String sample in samples) {
      test('$sample keeps separate Info.plists', () {
        final String legacy = read('${appDir(sample)}/ios/Runner/Info.plist');
        final String scene =
            read('${appDir(sample)}/ios/Runner/Info-Scene.plist');
        expect(legacy, isNot(contains('UIApplicationSceneManifest')));
        expect(scene, contains('UIApplicationSceneManifest'));
        expect(
          scene,
          contains(r'$(PRODUCT_MODULE_NAME).LifecycleTraceSceneDelegate'),
        );
        expect(
          read('${appDir(sample)}/ios/Runner.xcodeproj/project.pbxproj'),
          contains(
            r'INFOPLIST_FILE = "Runner/Info$(CIO_LIFECYCLE_INFOPLIST_SUFFIX).plist"',
          ),
        );
      });
    }

    test('build gives the instrumentation wrapper exact command ownership', () {
      final String build = read('apps/scripts/lifecycle_fixture_build.sh');
      final int config =
          build.indexOf('"\$FLUTTER" "\${FLUTTER_CONFIG_ARGS[@]}"');
      final int command = build.indexOf('XCODEBUILD_COMMAND=(xcodebuild');
      final int spm = build.indexOf('if [ "\$SAMPLE" = "spm" ]; then', command);
      final int spmInstrument = build.indexOf(
        'instrument_lifecycle_fixture_dependency.sh',
        spm,
      );
      final int spmCompile =
          build.indexOf('"\${XCODEBUILD_COMMAND[@]}"', spmInstrument);
      final int cocoa = build.indexOf('else', spmCompile);
      final int cocoaInstrument = build.indexOf(
        'instrument_lifecycle_fixture_dependency.sh',
        cocoa,
      );
      final int commandSeparator = build.indexOf('\n    --', cocoaInstrument);
      final int cocoaCompile =
          build.indexOf('"\${XCODEBUILD_COMMAND[@]}"', commandSeparator);
      expect(config, greaterThanOrEqualTo(0));
      expect(command, greaterThan(config));
      expect(spm, greaterThan(command));
      expect(spmInstrument, greaterThan(spm));
      expect(spmCompile, greaterThan(spmInstrument));
      expect(cocoa, greaterThan(spmCompile));
      expect(cocoaInstrument, greaterThan(cocoa));
      expect(commandSeparator, greaterThan(cocoaInstrument));
      expect(cocoaCompile, greaterThan(commandSeparator));
    });

    test('build serializes shared per-sample generation and compilation', () {
      final String build = read('apps/scripts/lifecycle_fixture_build.sh');
      final int lock = build.indexOf('if ! mkdir "\$LOCK_DIR"');
      final int config =
          build.indexOf('"\$FLUTTER" "\${FLUTTER_CONFIG_ARGS[@]}"');
      final int verify = build.indexOf('if [ "\$BUILT_MODE" != "\$MODE" ]');
      expect(lock, greaterThanOrEqualTo(0));
      expect(config, greaterThan(lock));
      expect(verify, greaterThan(config));
      expect(build, contains('trap release_build_lock EXIT'));
      expect(build, contains('another \$SAMPLE lifecycle build owns'));
    });
  });

  group('fail-closed disposable SDK patch', () {
    test('locks patch, original and result hashes', () {
      final String source =
          read('apps/scripts/instrument_lifecycle_fixture_dependency.sh');
      expect(source, contains('PATCH_SHA256='));
      expect(source, contains('ORIGINAL_SHA256='));
      expect(source, contains('PATCHED_SHA256='));
      expect(source, contains('[ -L "\$SOURCE_FILE" ]'));
      expect(source, contains('resolved Customer.io source escapes'));
      expect(source, contains('case "\$actual" in'));
    });

    test('patch carries identity and process-instance provenance', () {
      final String patch = read(
        'apps/lifecycle_fixture/customerio-ios-fcm-4.7.2-raw-launch.patch',
      );
      expect(patch, contains('object: NotificationCenter.default'));
      expect(patch, contains('CIO_LIFECYCLE_PROCESS_INSTANCE_ID'));
      expect(patch, contains('"process_instance_id"'));
      expect(patch, isNot(contains('completionHandler')));
    });
  });

  test('Dart producer uses build context and bounded async persistence', () {
    final String source = read(
      'apps/lifecycle_fixture/dart/lib/lifecycle_trace_recorder.dart',
    );
    expect(source, contains('String.fromEnvironment('));
    expect(source, isNot(contains('Platform.environment[')));
    expect(source, contains('Queue<Map<String, Object?>>'));
    expect(source, contains('scheduleMicrotask(_pump)'));
    expect(source, contains("'main_thread': false"));
    final String callback = _bodyOfDart(source, 'didChangeAppLifecycleState');
    expect(callback, isNot(contains('writeAsString')));
    expect(callback, isNot(contains('writeLine')));
    expect(callback, isNot(contains('await ')));
    expect(source, isNot(contains("'dart.")));
  });

  group('toolchain and canonical contract', () {
    for (final String sample in samples) {
      test('$sample pins Flutter 3.44.8', () {
        expect(read('${appDir(sample)}/.flutter-version').trim(), '3.44.8');
        expect(
          read('${appDir(sample)}/pubspec.yaml'),
          contains("flutter: '>=3.44.8'"),
        );
      });
    }
    test('published package minimum remains unchanged', () {
      final String pubspec = read('pubspec.yaml');
      expect(pubspec, contains('sdk: ">=2.17.6 <4.0.0"'));
      expect(pubspec, contains('flutter: ">=2.5.0"'));
    });
    test('lock owns exactly 18 files at corrected source commit', () {
      final String lock =
          read('docs/dev-notes/ios27-lifecycle-contract-v1.lock.json');
      expect('"path":'.allMatches(lock).length, 18);
      expect(
        lock,
        contains(
          '"source_commit": "5b8c02e4c85203d073a85da8abb2212b19867e68"',
        ),
      );
    });
  });
}

String _bodyOf(String source, String functionName) {
  final int signature = source.indexOf(
    RegExp(r'(?:override )?func [^{\n]*' + RegExp.escape(functionName)),
  );
  if (signature < 0) return '';
  final int next = source.indexOf('\n    override func ', signature + 1);
  return source.substring(signature, next < 0 ? source.length : next);
}

String _bodyOfDart(String source, String functionName) {
  final int signature = source.indexOf(functionName);
  if (signature < 0) return '';
  final int next = source.indexOf('\n  @', signature + 1);
  return source.substring(signature, next < 0 ? source.length : next);
}

Directory _repoRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/apps').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('could not locate repository root');
    }
    dir = parent;
  }
  return dir;
}
