import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty extracted API fails without replacing the baseline', () async {
    final Directory repository = Directory.current;
    final Directory fixture =
        await Directory.systemTemp.createTemp('customerio-api-extraction.');
    addTearDown(() => fixture.delete(recursive: true));

    final Directory scripts = Directory('${fixture.path}/scripts')
      ..createSync();
    File('${repository.path}/scripts/extract_api.sh')
        .copySync('${scripts.path}/extract_api.sh');
    File('${repository.path}/scripts/filter_api.dart')
        .copySync('${scripts.path}/filter_api.dart');

    const String originalBaseline = 'public final class Existing {}\n';
    final File baseline = File('${fixture.path}/customerio-flutter.api')
      ..writeAsStringSync(originalBaseline);

    final Directory binaries = Directory('${fixture.path}/bin')..createSync();
    final File flutter = File('${binaries.path}/flutter')
      ..writeAsStringSync(r'''#!/bin/bash
set -e
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    printf '%s\n' '{"packageApi":{"packageName":"customer_io","packageVersion":"test","interfaceDeclarations":[]}}' > "$2"
    exit 0
  fi
  shift
done
exit 2
''');
    final ProcessResult chmod = await Process.run(
      'chmod',
      <String>['+x', flutter.path],
    );
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');

    final ProcessResult result = await Process.run(
      'bash',
      <String>['scripts/extract_api.sh'],
      workingDirectory: fixture.path,
      environment: <String, String>{
        ...Platform.environment,
        'PATH': '${binaries.path}:${Platform.environment['PATH']}',
      },
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('contains no public classes'));
    expect(baseline.readAsStringSync(), originalBaseline);
    expect(
      fixture
          .listSync()
          .whereType<File>()
          .where((File file) => file.path.contains('.customerio-flutter.api.')),
      isEmpty,
    );
  });

  test('duplicate class names are ordered by source file', () async {
    final Directory fixture =
        await Directory.systemTemp.createTemp('customerio-api-ordering.');
    addTearDown(() => fixture.delete(recursive: true));

    Map<String, Object> declaration(String source, String fieldName) =>
        <String, Object>{
          'name': 'InAppMessage',
          'isDeprecated': false,
          'superTypeNames': <String>[],
          'relativePath': source,
          'executableDeclarations': <Object>[],
          'fieldDeclarations': <Object>[
            <String, Object>{
              'name': fieldName,
              'typeName': 'String',
              'isDeprecated': false,
              'isStatic': false,
              'isReadable': true,
              'isWriteable': false,
            },
          ],
        };

    final List<Map<String, Object>> declarations = <Map<String, Object>>[
      declaration('package:customer_io/z.dart', 'fromZ'),
      declaration('package:customer_io/a.dart', 'fromA'),
    ];

    Future<String> render(List<Map<String, Object>> interfaces) async {
      final File input = File('${fixture.path}/api.json')
        ..writeAsStringSync(
          '''{"packageApi":{"packageName":"customer_io","packageVersion":"test","interfaceDeclarations":${_jsonEncode(interfaces)}}}''',
        );
      final ProcessResult result = await Process.run(
        'dart',
        <String>['run', 'scripts/filter_api.dart', input.path],
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return result.stdout as String;
    }

    final String forward = await render(declarations);
    final String reversed = await render(declarations.reversed.toList());
    expect(reversed, forward);
    expect(forward.indexOf('fromA'), lessThan(forward.indexOf('fromZ')));
  });

  test('API check reports extraction failures without replacing baseline',
      () async {
    final Directory repository = Directory.current;
    final Directory fixture =
        await Directory.systemTemp.createTemp('customerio-api-check.');
    addTearDown(() => fixture.delete(recursive: true));

    final Directory scripts = Directory('${fixture.path}/scripts')
      ..createSync();
    File('${repository.path}/scripts/check_api_changes.sh')
        .copySync('${scripts.path}/check_api_changes.sh');
    final File extractor = File('${scripts.path}/extract_api.sh')
      ..writeAsStringSync(r'''#!/bin/bash
echo "sentinel extraction failure" >&2
exit 1
''');
    final ProcessResult chmod = await Process.run(
      'chmod',
      <String>['+x', extractor.path],
    );
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');

    const String originalBaseline = 'public final class Existing {}\n';
    final File baseline = File('${fixture.path}/customerio-flutter.api')
      ..writeAsStringSync(originalBaseline);

    final ProcessResult result = await Process.run(
      'bash',
      <String>['scripts/check_api_changes.sh'],
      workingDirectory: fixture.path,
    );

    expect(result.exitCode, 2);
    expect(result.stderr, contains('sentinel extraction failure'));
    expect(result.stderr, contains('API extraction failed'));
    expect(baseline.readAsStringSync(), originalBaseline);
    expect(File('${fixture.path}/customerio-flutter.api.backup').existsSync(),
        isFalse);
  });
}

String _jsonEncode(Object value) => const JsonEncoder().convert(value);
