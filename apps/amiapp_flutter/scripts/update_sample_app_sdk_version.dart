// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as path;

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final envPath = path.join(scriptDir.path, '../.env');
  final pubspecPath = path.join(scriptDir.path, '../pubspec.yaml');

  final env = DotEnv()..load([envPath]);
  String sdkVersion = env['SDK_VERSION'] ?? '';

  if (sdkVersion.isEmpty) {
    print(".env file doesn't contain an SDK_VERSION value, skip updating!");
    return;
  }

  File pubspecFile = File(pubspecPath);
  String pubspecContent = pubspecFile.readAsStringSync();

  String newDependency = 'customer_io: $sdkVersion';
  RegExp regex = RegExp(
    r'customer_io:\s*\n\s*path:\s*.*',
    multiLine: true,
  );
  pubspecContent = pubspecContent.replaceAll(regex, newDependency);

  pubspecFile.writeAsStringSync(pubspecContent);

  print("Successfully updated customer_io dependency: ($sdkVersion)'");
}
