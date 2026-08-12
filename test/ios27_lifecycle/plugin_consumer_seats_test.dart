import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies `apps/lifecycle_fixture/plugin-consumer-seats.lock.json`.
///
/// The lock says: "this canonical callback is received here in the sample, and
/// the code that delivers it is exactly this pinned plugin source". This test
/// re-derives all three halves rather than trusting the lock:
///
/// 1. every canonical name is a member of the vendored `cio-lifecycle-trace/1`
///    closed enums, so a seat cannot invent a callback;
/// 2. every sample call site still contains the consuming expression;
/// 3. every pinned plugin source resolves to the locked version and hashes to
///    the locked digest, and still declares the symbol the seat depends on.
///
/// Digest checks need resolved samples (`flutter pub get` with the isolated
/// PUB_CACHE). A missing resolution is a failure: consumer-seat verification
/// must never go green without checking the pinned plugin bytes.
void main() {
  final Directory repoRoot = _repoRoot();

  final Map<String, dynamic> lock = jsonDecode(
    File('${repoRoot.path}/apps/lifecycle_fixture/plugin-consumer-seats.lock.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;

  final Map<String, dynamic> traceSchema = jsonDecode(
    File('${repoRoot.path}/docs/dev-notes/ios27-lifecycle-trace-v1.schema.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;

  final List<dynamic> seats = lock['seats'] as List<dynamic>;

  test('lock is the expected schema and covers the four required seats', () {
    expect(lock['schema'], 'cio-lifecycle-plugin-consumer-seats/1');
    expect(lock['contract'], 'cio-lifecycle-trace/1');
    expect(
      seats.map((dynamic s) => (s as Map<String, dynamic>)['id']).toSet(),
      <String>{
        'remote-notification-received',
        'local-notification-response',
        'quick-action-received',
        'router-location-received',
      },
    );
  });

  group('canonical names come from the vendored contract', () {
    for (final dynamic entry in seats) {
      final Map<String, dynamic> seat = entry as Map<String, dynamic>;
      final Map<String, dynamic> canonical =
          seat['canonical'] as Map<String, dynamic>;

      test('${seat['id']}', () {
        for (final String field in <String>[
          'callback',
          'owner',
          'kind',
          'runtime',
          'provider',
        ]) {
          expect(
            _schemaEnum(traceSchema, field),
            contains(canonical[field]),
            reason: '$field "${canonical[field]}" is not in the closed enum',
          );
        }
        // A Dart receipt is an app-received record on the Flutter Dart seat.
        expect(canonical['runtime'], 'dart');
        expect(canonical['owner'], 'flutter-dart');
        expect(canonical['kind'], 'app-received');
        expect(canonical['callback'], startsWith('wrapper.app-received-'));
      });
    }
  });

  group('sample call sites still consume the seat', () {
    for (final dynamic entry in seats) {
      final Map<String, dynamic> seat = entry as Map<String, dynamic>;
      for (final dynamic site in seat['consumer_call_sites'] as List<dynamic>) {
        final Map<String, dynamic> callSite = site as Map<String, dynamic>;
        final String path = callSite['path'] as String;

        test('${seat['id']}: $path', () {
          final File file = File('${repoRoot.path}/$path');
          expect(file.existsSync(), isTrue, reason: 'missing $path');
          final String source = file.readAsStringSync();
          for (final dynamic expression
              in callSite['expressions'] as List<dynamic>) {
            expect(source, contains(expression as String));
          }

          // The CocoaPods sample symlinks lib/src to the SPM sample, so a
          // shared seat has to stay shared for the mapping to hold.
          for (final dynamic shared
              in (callSite['shared_with'] as List<dynamic>? ??
                  const <dynamic>[])) {
            final Link link = Link('${repoRoot.path}/${shared as String}');
            expect(link.existsSync(), isTrue,
                reason: 'expected symlink $shared');
          }
        });
      }
    }
  });

  group('pinned plugin sources', () {
    for (final String sample in <String>['spm', 'cocoapods']) {
      final File packageConfig = File(
        '${repoRoot.path}/apps/flutter_sample_$sample/.dart_tool/package_config.json',
      );
      if (!packageConfig.existsSync()) {
        test('$sample package resolution is available', () {
          fail('missing ${packageConfig.path}; run `flutter pub get` in the '
              '$sample sample with the isolated PUB_CACHE before this test');
        });
        continue;
      }
      final Map<String, Directory> packages = _resolvePackages(packageConfig);

      for (final dynamic entry in seats) {
        final Map<String, dynamic> seat = entry as Map<String, dynamic>;
        for (final dynamic pinned in seat['pinned_sources'] as List<dynamic>) {
          final Map<String, dynamic> source = pinned as Map<String, dynamic>;
          if (!(source['samples'] as List<dynamic>).contains(sample)) {
            continue;
          }
          final String package = source['package'] as String;
          final String version = source['version'] as String;
          final String path = source['path'] as String;

          test('$sample: $package $version $path', () {
            final Directory? root = packages[package];
            expect(root, isNotNull,
                reason: '$package is not a dependency of '
                    'the $sample sample');
            expect(
              root!.path.split(Platform.pathSeparator).last,
              '$package-$version',
              reason: 'resolved version differs from the locked version',
            );

            final File file = File('${root.path}/$path');
            expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

            final List<int> bytes = file.readAsBytesSync();
            expect(
              sha256.convert(bytes).toString(),
              source['sha256'],
              reason: 'pinned source changed; re-derive the seat before '
                  'updating the digest',
            );

            final String text = utf8.decode(bytes);
            for (final dynamic declaration
                in source['declarations'] as List<dynamic>) {
              expect(text, contains(declaration as String));
            }
          });
        }
      }
    }
  });
}

List<dynamic> _schemaEnum(Map<String, dynamic> schema, String field) {
  final Map<String, dynamic> properties =
      schema['properties'] as Map<String, dynamic>;
  final Map<String, dynamic> property =
      properties[field] as Map<String, dynamic>;
  final List<dynamic>? values = property['enum'] as List<dynamic>?;
  if (values != null) {
    return values;
  }
  // Indirect definitions live under $defs.
  final String ref = property[r'$ref'] as String;
  final String name = ref.split('/').last;
  final Map<String, dynamic> defs = schema[r'$defs'] as Map<String, dynamic>;
  return (defs[name] as Map<String, dynamic>)['enum'] as List<dynamic>;
}

Map<String, Directory> _resolvePackages(File packageConfig) {
  final Map<String, dynamic> config =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final Uri base = packageConfig.parent.uri;
  return <String, Directory>{
    for (final dynamic entry in config['packages'] as List<dynamic>)
      (entry as Map<String, dynamic>)['name'] as String:
          Directory.fromUri(base.resolve(entry['rootUri'] as String)),
  };
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
