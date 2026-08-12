import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const String _nativeLockSha256 =
    'f97f648a8bd0698b6bbb038d0707c2d821897e7a65eac5caf10c040cafe0dfde';
const String _nativeToolSha256 =
    '6d6ec827e0c858dde7d3694eec74f397a514a72305e8b77e3961f63070a15743';

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

  test('lock metadata names its source commit', () {
    expect(lock['schema'], 'cio-lifecycle-contract-lock/1');
    expect(lock['source_repository'], 'customerio/customerio-ios');
    expect(files.length, 18);
    expect(
      lock['source_commit'],
      '5b8c02e4c85203d073a85da8abb2212b19867e68',
    );
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
