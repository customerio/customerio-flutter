import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const String _nativeLockSha256 =
    '4571d00d89f8175cf29098e77f2cf863827d400a1f381b8f729b787fc7fcc64a';
const String _nativeToolSha256 =
    '03c48a30b287c58e5b611388980928ea08eb91385b52ac5e4dbdb1d32a23db28';

/// Re-derives the vendored contract lock from disk.
///
/// `scripts/ios27_lifecycle_contract.py` is the checked-in verifier and
/// is the one that can also reconcile against a `customerio-ios` checkout. This
/// test covers the same content identity from `flutter test`, so a bad vendor
/// cannot reach CI just because Python was not run.
void main() {
  final Directory repoRoot = _repoRoot();
  final File lockFile = File(
      '${repoRoot.path}/docs/dev-notes/ios27-lifecycle-contract-v1.lock.json');
  final Map<String, dynamic> lock =
      jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
  final List<dynamic> files = lock['files'] as List<dynamic>;

  test('native lock and verifier bytes are anchored', () {
    expect(
      sha256.convert(lockFile.readAsBytesSync()).toString(),
      _nativeLockSha256,
    );
    final File tool = File(
      '${repoRoot.path}/scripts/ios27_lifecycle_contract.py',
    );
    expect(tool.existsSync(), isTrue);
    expect(
      sha256.convert(tool.readAsBytesSync()).toString(),
      _nativeToolSha256,
    );
  });

  test('lock metadata names its reviewed content commit', () {
    expect(lock['schema'], 'cio-lifecycle-contract-lock/2');
    expect(lock['source_repository'], 'customerio/customerio-ios');
    expect(files.length, 18);
    expect(
      lock['pinned_content_commit'],
      '45009f814e8183a8feccb884efd50c4a2aff020a',
    );
    expect(lock['relock_note'], isNotEmpty);
  });

  group('every vendored file matches its locked digest', () {
    for (final dynamic entry in files) {
      final Map<String, dynamic> file = entry as Map<String, dynamic>;
      final String path = file['path'] as String;

      test(path, () {
        final File vendored = File('${repoRoot.path}/$path');
        expect(vendored.existsSync(), isTrue, reason: 'missing $path');
        expect(
          sha256.convert(vendored.readAsBytesSync()).toString(),
          file['sha256'],
          reason: 'the canonical package is owned by customerio-ios and must '
              'not be edited here',
        );
      });
    }
  });

  test('no unlocked files were added under the vendored root', () {
    final Set<String> locked = <String>{
      ...files
          .map((dynamic f) => (f as Map<String, dynamic>)['path'] as String),
      'docs/dev-notes/ios27-lifecycle-contract-v1.lock.json',
    };
    final Directory root = Directory('${repoRoot.path}/docs/dev-notes');
    final List<String> present = root
        .listSync(recursive: true)
        .whereType<File>()
        .map((File f) => f.path.substring(repoRoot.path.length + 1))
        // Running the vendored validator leaves build artefacts behind; they
        // are git-ignored and are not part of the contract package.
        .where((String p) => !p.contains('__pycache__'))
        .toList();

    expect(present.toSet().difference(locked), isEmpty);
  });
}

Directory _repoRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/apps').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
          'could not locate repository root from ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}
