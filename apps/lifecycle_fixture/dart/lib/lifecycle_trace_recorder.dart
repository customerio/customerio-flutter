import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Compile-time fixture context supplied by the reproducible lifecycle build.
///
/// iOS does not expose the native process environment through
/// [Platform.environment] to Dart. Flutter's standard `DART_DEFINES` build
/// input carries the same per-run IDs without adding an application channel.
final class LifecycleTraceDartContext {
  const LifecycleTraceDartContext({
    required this.outputBasename,
    required this.manifestId,
    required this.runId,
    required this.streamId,
    required this.processInstanceId,
    required this.evidenceLevel,
    required this.provider,
  });

  static final RegExp _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _safeBasename = RegExp(r'^[a-zA-Z0-9._-]{1,128}$');

  final String outputBasename;
  final String manifestId;
  final String runId;
  final String streamId;
  final String processInstanceId;
  final String evidenceLevel;
  final String provider;

  static LifecycleTraceDartContext? fromBuildEnvironment() {
    const String outputBasename = String.fromEnvironment(
      'CIO_LIFECYCLE_DART_OUTPUT_BASENAME',
    );
    const String manifestId = String.fromEnvironment(
      'CIO_LIFECYCLE_MANIFEST_ID',
    );
    const String runId = String.fromEnvironment('CIO_LIFECYCLE_RUN_ID');
    const String streamId = String.fromEnvironment(
      'CIO_LIFECYCLE_DART_STREAM_ID',
    );
    const String processInstanceId = String.fromEnvironment(
      'CIO_LIFECYCLE_PROCESS_INSTANCE_ID',
    );
    const String scenario = String.fromEnvironment('CIO_LIFECYCLE_SCENARIO');
    const String evidenceLevel = String.fromEnvironment(
      'CIO_LIFECYCLE_EVIDENCE_LEVEL',
    );
    const String integration = String.fromEnvironment(
      'CIO_LIFECYCLE_INTEGRATION',
    );
    const String provider = String.fromEnvironment('CIO_LIFECYCLE_PROVIDER');

    if (!_safeBasename.hasMatch(outputBasename) ||
        !_canonicalUuid.hasMatch(manifestId) ||
        !_canonicalUuid.hasMatch(runId) ||
        !_canonicalUuid.hasMatch(streamId) ||
        !_canonicalUuid.hasMatch(processInstanceId) ||
        scenario != 'icon-cold-launch' ||
        (evidenceLevel != 'diagnostic' &&
            evidenceLevel != 'L2' &&
            evidenceLevel != 'L3') ||
        integration != 'flutter' ||
        provider != 'none') {
      return null;
    }
    return const LifecycleTraceDartContext(
      outputBasename: outputBasename,
      manifestId: manifestId,
      runId: runId,
      streamId: streamId,
      processInstanceId: processInstanceId,
      evidenceLevel: evidenceLevel,
      provider: provider,
    );
  }
}

/// Async persistence boundary used by the bounded recorder queue.
abstract interface class LifecycleTraceDartPersistence {
  Future<void> writeLine(String line);

  Future<void> writeReceipt(String json);
}

final class FileLifecycleTraceDartPersistence
    implements LifecycleTraceDartPersistence {
  FileLifecycleTraceDartPersistence._(
    this.output,
    this.receipt,
    this.pendingReceipt,
    this._writePendingReceipt,
  );

  final File output;
  final File receipt;
  final File pendingReceipt;
  final Future<void> Function(File file, String contents) _writePendingReceipt;

  static FileLifecycleTraceDartPersistence? claim(String basename) {
    return _claimInDirectory(Directory.systemTemp, basename, _writeAndFlush);
  }

  @visibleForTesting
  static FileLifecycleTraceDartPersistence? claimForTest(
    Directory directory,
    String basename, {
    Future<void> Function(File file, String contents)? writePendingReceipt,
  }) {
    return _claimInDirectory(
      directory,
      basename,
      writePendingReceipt ?? _writeAndFlush,
    );
  }

  static FileLifecycleTraceDartPersistence? _claimInDirectory(
    Directory directory,
    String basename,
    Future<void> Function(File file, String contents) writePendingReceipt,
  ) {
    final File output = File('${directory.path}/$basename');
    final File receipt = File('${output.path}.receipt.json');
    final File pendingReceipt = File('${receipt.path}.pending');
    try {
      final FileSystemEntityType outputType = FileSystemEntity.typeSync(
        output.path,
        followLinks: false,
      );
      if ((outputType != FileSystemEntityType.notFound &&
              outputType != FileSystemEntityType.file) ||
          (outputType == FileSystemEntityType.file &&
              output.lengthSync() != 0) ||
          FileSystemEntity.typeSync(receipt.path, followLinks: false) !=
              FileSystemEntityType.notFound ||
          FileSystemEntity.typeSync(pendingReceipt.path, followLinks: false) !=
              FileSystemEntityType.notFound ||
          !output.parent.existsSync()) {
        return null;
      }
      if (outputType == FileSystemEntityType.notFound) {
        output.createSync(exclusive: true);
      }
      pendingReceipt.createSync(exclusive: true);
      return FileLifecycleTraceDartPersistence._(
        output,
        receipt,
        pendingReceipt,
        writePendingReceipt,
      );
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writeLine(String line) =>
      output.writeAsString('$line\n', mode: FileMode.append, flush: true);

  @override
  Future<void> writeReceipt(String json) async {
    await _writePendingReceipt(pendingReceipt, '$json\n');
    if (FileSystemEntity.typeSync(receipt.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('receipt path already exists', receipt.path);
    }
    await pendingReceipt.rename(receipt.path);
  }

  static Future<void> _writeAndFlush(File file, String contents) =>
      file.writeAsString(contents, mode: FileMode.write, flush: true);
}

/// Fixture-only canonical Dart stream for Flutter's real lifecycle observer.
///
/// The lifecycle callback captures immutable record data and enqueues it only.
/// Ordered file persistence and the final receipt run asynchronously afterward.
final class LifecycleTraceDartRecorder with WidgetsBindingObserver {
  LifecycleTraceDartRecorder._({
    required this.context,
    required this.persistence,
    required this.processId,
    required this.bufferCapacity,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String _prefix = 'CIO-LIFECYCLE-TRACE ';
  static LifecycleTraceDartRecorder? _shared;

  final LifecycleTraceDartContext context;
  final LifecycleTraceDartPersistence persistence;
  final int processId;
  final int bufferCapacity;
  final DateTime Function() _now;
  final Stopwatch _clock = Stopwatch()..start();
  final Queue<Map<String, Object?>> _pending = Queue<Map<String, Object?>>();
  final Completer<void> _drained = Completer<void>();

  int _sequence = 0;
  int _outstanding = 0;
  int _emitted = 0;
  int _lastEmittedSequence = 0;
  int _dropped = 0;
  int _highWatermark = 0;
  bool _pumping = false;
  bool _closing = false;
  bool _ended = false;
  bool _hasOccurrence = false;

  Future<void> get drained => _drained.future;

  static LifecycleTraceDartRecorder? attachFromBuildEnvironment() {
    if (_shared case final LifecycleTraceDartRecorder recorder) {
      return recorder;
    }
    final LifecycleTraceDartContext? context =
        LifecycleTraceDartContext.fromBuildEnvironment();
    if (context == null) {
      debugPrint('CIO-LIFECYCLE-DART disabled: invalid build context');
      return null;
    }
    final FileLifecycleTraceDartPersistence? persistence =
        FileLifecycleTraceDartPersistence.claim(context.outputBasename);
    if (persistence == null) {
      debugPrint('CIO-LIFECYCLE-DART disabled: output claim failed');
      return null;
    }
    final LifecycleTraceDartRecorder recorder = LifecycleTraceDartRecorder._(
      context: context,
      persistence: persistence,
      processId: pid,
      bufferCapacity: 256,
    );
    recorder._record(
      owner: 'trace-recorder',
      kind: 'trace-control',
      callback: 'trace.scenario-start',
      phase: 'state-change',
    );
    WidgetsBinding.instance.addObserver(recorder);
    _shared = recorder;
    debugPrint('CIO-LIFECYCLE-DART armed');
    return recorder;
  }

  @visibleForTesting
  factory LifecycleTraceDartRecorder.forTest({
    required LifecycleTraceDartContext context,
    required LifecycleTraceDartPersistence persistence,
    int processId = 42,
    int bufferCapacity = 256,
    DateTime Function()? now,
  }) {
    final LifecycleTraceDartRecorder recorder = LifecycleTraceDartRecorder._(
      context: context,
      persistence: persistence,
      processId: processId,
      bufferCapacity: bufferCapacity,
      now: now,
    );
    recorder._record(
      owner: 'trace-recorder',
      kind: 'trace-control',
      callback: 'trace.scenario-start',
      phase: 'state-change',
    );
    return recorder;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ended || state != AppLifecycleState.resumed) {
      return;
    }
    _record(
      owner: 'flutter-dart',
      kind: 'app-received',
      callback: 'wrapper.app-lifecycle-state',
      phase: 'state-change',
      enums: const <String, String>{'app_state': 'active'},
    );
  }

  /// Records the actual Dart `main` bootstrap seat and closes this icon-launch
  /// stream. FIFO persistence guarantees the seat drains before scenario-end
  /// and the final receipt, without doing callback-thread file I/O.
  void didEnterDartMain() {
    if (_ended) {
      return;
    }
    _record(
      owner: 'flutter-dart',
      kind: 'app-received',
      callback: 'flutter.dart-main-entered',
      phase: 'entry',
    );
    _record(
      owner: 'trace-recorder',
      kind: 'trace-control',
      callback: 'trace.scenario-end',
      phase: 'state-change',
    );
    _ended = true;
    WidgetsBinding.instance.removeObserver(this);
    _closeAfterDrain();
  }

  @visibleForTesting
  bool recordForTest() => _record(
    owner: 'flutter-dart',
    kind: 'app-received',
    callback: 'wrapper.app-lifecycle-state',
    phase: 'state-change',
  );

  @visibleForTesting
  void closeForTest() {
    if (!_ended) {
      _record(
        owner: 'trace-recorder',
        kind: 'trace-control',
        callback: 'trace.scenario-end',
        phase: 'state-change',
      );
      _ended = true;
    }
    _closeAfterDrain();
  }

  bool _record({
    required String owner,
    required String kind,
    required String callback,
    required String phase,
    Map<String, String> enums = const <String, String>{},
  }) {
    if (_closing || _outstanding >= bufferCapacity) {
      _dropped += 1;
      return false;
    }
    final bool hasOccurrence =
        kind != 'trace-control' && context.evidenceLevel != 'diagnostic';
    if (hasOccurrence) {
      _hasOccurrence = true;
    }
    _sequence += 1;
    _outstanding += 1;
    _highWatermark = _outstanding > _highWatermark
        ? _outstanding
        : _highWatermark;
    _pending.add(<String, Object?>{
      'schema': 'cio-lifecycle-trace/1',
      'manifest_id': context.manifestId,
      'run_id': context.runId,
      'stream_id': context.streamId,
      'sequence': _sequence,
      'monotonic_ms': _clock.elapsedMilliseconds,
      'captured_at': _now().toUtc().toIso8601String(),
      'process_id': processId,
      'integration': 'flutter',
      'runtime': 'dart',
      'provider': context.provider,
      'scenario': 'icon-cold-launch',
      'evidence_level': context.evidenceLevel,
      'owner': owner,
      'kind': kind,
      'callback': callback,
      'phase': phase,
      'main_thread': false,
      'payload_summary': <String, Object>{
        'flags': const <String, bool>{},
        'counts': const <String, int>{},
        'enums': enums,
      },
      'correlation': hasOccurrence
          ? const <String, String>{'occurrence': 'occurrence-1'}
          : null,
      'completion': null,
      'recorder': _snapshot(),
    });
    _schedulePump();
    return true;
  }

  void _schedulePump() {
    if (_pumping) {
      return;
    }
    _pumping = true;
    scheduleMicrotask(_pump);
  }

  Future<void> _pump() async {
    while (_pending.isNotEmpty) {
      final Map<String, Object?> record = _pending.removeFirst();
      try {
        await persistence.writeLine('$_prefix${jsonEncode(record)}');
        _emitted += 1;
        _lastEmittedSequence = record['sequence']! as int;
      } on Object {
        _dropped += 1;
      } finally {
        _outstanding -= 1;
      }
    }
    _pumping = false;
    if (_pending.isNotEmpty) {
      _schedulePump();
      return;
    }
    if (_closing) {
      await _writeReceipt();
    }
  }

  void _closeAfterDrain() {
    _closing = true;
    _schedulePump();
  }

  Future<void> _writeReceipt() async {
    if (_drained.isCompleted) {
      return;
    }
    final Map<String, Object> receipt = <String, Object>{
      'drained_at': _now().toUtc().toIso8601String(),
      'last_assigned_sequence': _sequence,
      'last_emitted_sequence': _lastEmittedSequence,
      'emitted_records': _emitted,
      ..._snapshot(),
    };
    try {
      await persistence.writeReceipt(jsonEncode(receipt));
    } on Object {
      // Evidence fails closed because the receipt is absent. Instrumentation
      // must not surface an unhandled async error into the sample app.
      debugPrint('CIO-LIFECYCLE-DART receipt persistence failed');
    }
    _drained.complete();
  }

  Map<String, Object> _snapshot() => <String, Object>{
    'dropped_records_total': _dropped,
    'alias_counts': <String, int>{
      'occurrence': _hasOccurrence ? 1 : 0,
      'delivery': 0,
      'request': 0,
      'scene': 0,
      'url': 0,
      'closure': 0,
    },
    'alias_overflow': false,
    'alias_overflow_namespaces': const <String>[],
    'buffer_high_watermark': _highWatermark,
    'buffer_capacity': bufferCapacity,
  };
}
