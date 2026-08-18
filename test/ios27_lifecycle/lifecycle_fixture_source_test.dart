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

  test('sample apps compile byte-identical Swift trace support', () {
    for (final String filename in <String>[
      'LifecycleTraceEvidence.swift',
      'LifecycleTraceFlutterFixture.swift',
      'LifecycleTraceModel.swift',
      'LifecycleTraceProbe.swift',
      'LifecycleTraceRawLaunchMarker.swift',
      'LifecycleTraceRecorder.swift',
      'LifecycleTraceSceneDelegate.swift',
    ]) {
      expect(
        File('${repoRoot.path}/${appDir('spm')}/ios/Runner/$filename')
            .readAsBytesSync(),
        File('${repoRoot.path}/${appDir('cocoapods')}/ios/Runner/$filename')
            .readAsBytesSync(),
        reason: '$filename must have one evidence meaning in both samples',
      );
    }
  });

  group('real launch and implicit-engine consumer seats', () {
    for (final String sample in samples) {
      test('$sample registers each engine through one guarded helper', () {
        final String source =
            read('${appDir(sample)}/ios/Runner/AppDelegate.swift');
        final String bootstrap =
            _bodyOf(source, 'didInitializeImplicitFlutterEngine');
        final String helper = _bodyOf(source, 'registerPluginsIfNeeded');
        final String launch = _bodyOf(source, 'didFinishLaunchingWithOptions');
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
        expect(helper, contains('guard !registry.hasPlugin('));
        expect(
          helper,
          contains('GeneratedPluginRegistrant.register(with: registry)'),
        );
        expect(
          helper,
          contains('permissionHandler.register(with: registrar.messenger())'),
        );
        expect(
          helper,
          contains(
            'lifecycleLogger.error("Permission channel registrar unavailable; registration will retry on the next engine seat")',
          ),
        );
        expect(
          bootstrap,
          contains(
              'registerPluginsIfNeeded(with: engineBridge.pluginRegistry)'),
        );
        expect(launch, contains('registerPluginsIfNeeded(with: self)'));
        expect(
          'GeneratedPluginRegistrant.register('.allMatches(source).length,
          1,
        );
        expect('permissionHandler.register('.allMatches(source).length, 1);
        expect(launch, isNot(contains('GeneratedPluginRegistrant.register(')));
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

      test('$sample starts and retains the platform probe observer once', () {
        final String fixture = read(
          '${appDir(sample)}/ios/Runner/LifecycleTraceFlutterFixture.swift',
        );
        expect(
          fixture,
          contains(
            'var platformProbeObserver: LifecycleTracePlatformProbeObserver?',
          ),
        );
        expect(
          'state.platformProbeObserver = LifecycleTracePlatformProbeObserver()'
              .allMatches(fixture)
              .length,
          1,
        );
        expect(
          _bodyOf(fixture, 'startIfConfigured'),
          contains('installPlatformProbeObserverOnce()'),
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
      expect(source, contains('trap restore_cocoapods_source_on_exit EXIT'));
      expect(source, contains('if ! restore_cocoapods_source; then'));
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
    expect(source, contains("'occurrence': 'occurrence-1'"));
    expect(source, contains("'occurrence': _hasOccurrence ? 1 : 0"));
    final String callback = _bodyOfDart(source, 'didChangeAppLifecycleState');
    expect(callback, isNot(contains('writeAsString')));
    expect(callback, isNot(contains('writeLine')));
    expect(callback, isNot(contains('await ')));
    expect(source, isNot(contains("'dart.")));
  });

  for (final String sample in samples) {
    test('$sample records the compiled scene-manifest state at start', () {
      final String probe = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceProbe.swift',
      );
      expect(
        probe,
        contains(
          'Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") != nil',
        ),
      );
      expect(
          probe, contains('flags: [.sceneManifestActive: hasSceneManifest]'));
    });
  }

  for (final String sample in samples) {
    test('$sample assigns one run-scoped occurrence to L2/L3 Swift seats', () {
      final String model = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceModel.swift',
      );
      final String recorder = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceRecorder.swift',
      );
      expect(model, contains('case occurrence'));
      expect(recorder, contains('observation.correlations[.occurrence]'));
      expect(
          recorder, contains('.string(context.activationOccurrenceIdentity)'));
      expect(recorder, contains('occurrence: aliasTables[.occurrence]'));
    });

    test('$sample cleans up only after an accepted scenario end drains', () {
      final String probe = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceProbe.swift',
      );
      final String endScenario = _bodyOf(probe, 'endScenario');
      expect(
        endScenario,
        contains(
          'let accepted = recorder.endScenario(after: terminal) { _ in\n'
          '            handleEndCompletion()\n'
          '        }\n'
          '        guard accepted else { return }',
        ),
      );
      final String recorder = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceRecorder.swift',
      );
      expect(
        recorder,
        contains(
          'guard canEndScenarioLocked(), terminalIsValidForScenarioLocked(terminal) else {\n'
          '            stateLock.unlock()\n'
          '            return false',
        ),
      );
      expect(
        recorder,
        isNot(
          contains(
            'stateLock.unlock()\n'
            '            completion(nil)\n'
            '            return false',
          ),
        ),
      );
      expect(
        recorder,
        isNot(contains('@discardableResult\n    public func endScenario(')),
      );
    });

    test('$sample closes icon launch with the declared topology terminal', () {
      final String fixture = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceFlutterFixture.swift',
      );
      expect(
        fixture,
        contains('recorder.hostTopology == .appDelegateOnly'),
      );
      expect(fixture, contains('? .activeApplication'));
      expect(fixture, contains(': .activeScene'));
    });

    test('$sample recorder drops only the oldest pending record on overflow',
        () {
      final String recorder = read(
        '${appDir(sample)}/ios/Runner/LifecycleTraceRecorder.swift',
      );
      expect(
        recorder,
        contains(
          'let displacedOldestRecord = bufferedRecordCountLocked() > bufferCapacity\n'
          '        if displacedOldestRecord, !evictOldestBufferedRecordLocked() {\n'
          '            captureFailed = true\n'
          '            pendingRecords.removeAll()\n'
          '            return record\n'
          '        }\n'
          '        let observedBufferLoad = max(\n'
          '            pendingRecords.contains(where: { \$0.callback == .traceScenarioStart }) ? 1 : 0,\n'
          '            bufferedRecordCountLocked()\n'
          '        )\n'
          '        bufferHighWatermark = max(bufferHighWatermark, observedBufferLoad)',
        ),
      );
      expect(recorder,
          isNot(contains('droppedRecordsTotal += pendingRecords.count')));
      expect(recorder, contains('droppedRecordsTotal += 1'));
      expect(
        recorder,
        contains(
          'private func evictOldestBufferedRecordLocked() -> Bool {\n'
          '        guard let evictionIndex = pendingRecords.firstIndex(where: {\n'
          '            \$0.callback != .traceScenarioStart\n'
          '        }) else { return false }\n'
          '        pendingRecords.remove(at: evictionIndex)\n'
          '        droppedRecordsTotal += 1\n'
          '        return true',
        ),
      );
      expect(
        recorder,
        contains(
          'if displacedOldestRecord {\n'
          '            refreshPendingBufferAccountingLocked()\n'
          '        }',
        ),
      );
      expect(
        recorder,
        contains(
          'guard pendingRecords[index].callback != .traceScenarioStart else { continue }\n'
          '            let snapshot = pendingRecords[index].recorder\n'
          '            pendingRecords[index].recorder = LifecycleTraceRecorderSnapshot(',
        ),
      );
    });
  }

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
    test('lock owns exactly 18 files at reviewed content commit', () {
      final String lock =
          read('docs/dev-notes/ios27-lifecycle-contract-v1.lock.json');
      expect('"path":'.allMatches(lock).length, 18);
      expect(
        lock,
        contains(
          '"pinned_content_commit": "45009f814e8183a8feccb884efd50c4a2aff020a"',
        ),
      );
    });
  });
}

String _bodyOf(String source, String functionName) {
  final List<RegExpMatch> declarations = RegExp(
    r'^    (?:(?:public|private|internal|fileprivate|open|override|static|class|mutating|nonmutating|final) )*func ',
    multiLine: true,
  ).allMatches(source).toList();
  for (int index = 0; index < declarations.length; index += 1) {
    final int start = declarations[index].start;
    final int end = index + 1 < declarations.length
        ? declarations[index + 1].start
        : source.length;
    final String candidate = source.substring(start, end);
    final int signatureEnd = candidate.indexOf('{');
    if (signatureEnd >= 0 &&
        candidate.substring(0, signatureEnd).contains(functionName)) {
      return candidate;
    }
  }
  return '';
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
