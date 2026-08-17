import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cio_lifecycle_flutter_fixture/lifecycle_trace_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const LifecycleTraceDartContext context = LifecycleTraceDartContext(
    outputBasename: 'trace.ndjson',
    manifestId: '12345678-1234-4123-8123-123456789abc',
    runId: '22345678-1234-4123-8123-123456789abc',
    streamId: '32345678-1234-4123-8123-123456789abc',
    processInstanceId: '42345678-1234-4123-8123-123456789abc',
    evidenceLevel: 'L2',
    provider: 'none',
  );

  test(
    'real lifecycle callback only enqueues and receipt follows drain',
    () async {
      final _DelayedPersistence persistence = _DelayedPersistence();
      final LifecycleTraceDartRecorder recorder =
          LifecycleTraceDartRecorder.forTest(
            context: context,
            persistence: persistence,
          );

      recorder.didChangeAppLifecycleState(AppLifecycleState.resumed);
      recorder.didEnterDartMain();

      expect(
        persistence.lines,
        isEmpty,
        reason: 'the callback must not synchronously persist',
      );
      expect(persistence.receipt, isNull);

      persistence.release();
      await recorder.drained;

      expect(persistence.lines, hasLength(4));
      expect(persistence.lines.map(_callback), <String>[
        'trace.scenario-start',
        'wrapper.app-lifecycle-state',
        'flutter.dart-main-entered',
        'trace.scenario-end',
      ]);
      expect(_record(persistence.lines[2])['kind'], 'app-received');
      expect(_record(persistence.lines.first)['correlation'], isNull);
      expect(_record(persistence.lines.last)['correlation'], isNull);
      expect(_record(persistence.lines[1])['correlation'], <String, Object?>{
        'occurrence': 'occurrence-1',
      });
      expect(_record(persistence.lines[2])['correlation'], <String, Object?>{
        'occurrence': 'occurrence-1',
      });
      expect(
        persistence.lines
            .map(_record)
            .every(
              (Map<String, Object?> record) => record['main_thread'] == false,
            ),
        isTrue,
      );
      expect(_receipt(persistence)['emitted_records'], 4);
      expect(_receipt(persistence)['dropped_records_total'], 0);
      expect(
        (_receipt(persistence)['alias_counts']!
            as Map<String, Object?>)['occurrence'],
        1,
      );
    },
  );

  test('bounded queue reports overflow without blocking the caller', () async {
    final _DelayedPersistence persistence = _DelayedPersistence();
    final LifecycleTraceDartRecorder recorder =
        LifecycleTraceDartRecorder.forTest(
          context: context,
          persistence: persistence,
          bufferCapacity: 1,
        );

    expect(recorder.recordForTest(), isFalse);
    recorder.closeForTest();
    persistence.release();
    await recorder.drained;

    expect(persistence.lines, hasLength(1));
    expect(_receipt(persistence)['buffer_high_watermark'], 1);
    expect(_receipt(persistence)['dropped_records_total'], 2);
  });

  test('failed async persistence is reflected in the final receipt', () async {
    final _FailingPersistence persistence = _FailingPersistence();
    final LifecycleTraceDartRecorder recorder =
        LifecycleTraceDartRecorder.forTest(
          context: context,
          persistence: persistence,
        );

    recorder.didEnterDartMain();
    await recorder.drained;

    expect(persistence.lines, hasLength(2));
    expect(_receipt(persistence)['emitted_records'], 2);
    expect(_receipt(persistence)['dropped_records_total'], 1);
  });

  test('failed receipt is swallowed and cannot perturb the app', () async {
    final _ReceiptFailingPersistence persistence = _ReceiptFailingPersistence();
    final LifecycleTraceDartRecorder recorder =
        LifecycleTraceDartRecorder.forTest(
          context: context,
          persistence: persistence,
        );

    recorder.didEnterDartMain();

    await expectLater(recorder.drained, completes);
    expect(persistence.lines, hasLength(3));
    expect(persistence.receipt, isNull);
  });

  test('file receipt is invisible until its complete atomic publish', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'mbl2232-dart-receipt-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final Completer<void> gate = Completer<void>();
    final FileLifecycleTraceDartPersistence? persistence =
        FileLifecycleTraceDartPersistence.claimForTest(
          directory,
          'trace.ndjson',
          writePendingReceipt: (File file, String contents) async {
            await gate.future;
            await file.writeAsString(
              contents,
              mode: FileMode.write,
              flush: true,
            );
          },
        );
    expect(persistence, isNotNull);
    expect(persistence!.pendingReceipt.existsSync(), isTrue);
    expect(persistence.receipt.existsSync(), isFalse);

    final Future<void> publishing = persistence.writeReceipt('{"done":true}');
    await Future<void>.delayed(Duration.zero);
    expect(persistence.receipt.existsSync(), isFalse);

    gate.complete();
    await publishing;
    expect(persistence.pendingReceipt.existsSync(), isFalse);
    expect(
      jsonDecode(await persistence.receipt.readAsString()),
      <String, Object>{'done': true},
    );
  });

  test('file receipt refuses preexisting and raced final targets', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'mbl2232-dart-receipt-target-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File preexisting = File(
      '${directory.path}/preexisting.ndjson.receipt.json',
    )..writeAsStringSync('{}\n');
    expect(
      FileLifecycleTraceDartPersistence.claimForTest(
        directory,
        'preexisting.ndjson',
      ),
      isNull,
    );
    preexisting.deleteSync();
    Link(preexisting.path).createSync('/dev/null');
    expect(
      FileLifecycleTraceDartPersistence.claimForTest(
        directory,
        'preexisting.ndjson',
      ),
      isNull,
    );

    final Completer<void> gate = Completer<void>();
    final FileLifecycleTraceDartPersistence persistence =
        FileLifecycleTraceDartPersistence.claimForTest(
          directory,
          'raced.ndjson',
          writePendingReceipt: (File file, String contents) async {
            await gate.future;
            await file.writeAsString(
              contents,
              mode: FileMode.write,
              flush: true,
            );
          },
        )!;
    final Future<void> publishing = persistence.writeReceipt('{"done":true}');
    persistence.receipt.writeAsStringSync('{"spoofed":true}\n');
    gate.complete();
    await expectLater(publishing, throwsA(isA<FileSystemException>()));
    expect(jsonDecode(persistence.receipt.readAsStringSync()), <String, Object>{
      'spoofed': true,
    });
  });
}

Map<String, Object?> _record(String line) =>
    jsonDecode(line.substring('CIO-LIFECYCLE-TRACE '.length))
        as Map<String, Object?>;

String _callback(String line) => _record(line)['callback']! as String;

Map<String, Object?> _receipt(_MemoryPersistence persistence) =>
    jsonDecode(persistence.receipt!) as Map<String, Object?>;

abstract base class _MemoryPersistence
    implements LifecycleTraceDartPersistence {
  final List<String> lines = <String>[];
  String? receipt;

  @override
  Future<void> writeReceipt(String json) async {
    receipt = json;
  }
}

final class _DelayedPersistence extends _MemoryPersistence {
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> writeLine(String line) async {
    await _gate.future;
    lines.add(line);
  }
}

final class _FailingPersistence extends _MemoryPersistence {
  bool _failed = false;

  @override
  Future<void> writeLine(String line) async {
    if (!_failed) {
      _failed = true;
      throw const FileSystemExceptionForTest();
    }
    lines.add(line);
  }
}

final class _ReceiptFailingPersistence extends _MemoryPersistence {
  @override
  Future<void> writeLine(String line) async {
    lines.add(line);
  }

  @override
  Future<void> writeReceipt(String json) async {
    throw const FileSystemExceptionForTest();
  }
}

final class FileSystemExceptionForTest implements Exception {
  const FileSystemExceptionForTest();
}
