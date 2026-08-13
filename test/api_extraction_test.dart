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

    Map<String, Object> declaration(String source) => <String, Object>{
          'name': 'InAppMessage',
          'isDeprecated': false,
          'superTypeNames': <String>[],
          'relativePath': source,
          'executableDeclarations': <Object>[],
          'fieldDeclarations': <Object>[],
        };

    final List<Map<String, Object>> declarations = <Map<String, Object>>[
      declaration('package:customer_io/z.dart'),
      declaration('package:customer_io/a.dart'),
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
  });
}

String _jsonEncode(Object value) => const JsonEncoder().convert(value);
