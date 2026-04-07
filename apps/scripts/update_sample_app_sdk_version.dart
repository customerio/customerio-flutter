// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run apps/scripts/update_sample_app_sdk_version.dart <app_directory>');
    print('Example: dart run apps/scripts/update_sample_app_sdk_version.dart apps/flutter_sample_spm');
    exit(1);
  }

  final appDir = args[0];
  final envFile = File('$appDir/.env');
  final pubspecFile = File('$appDir/pubspec.yaml');

  if (!envFile.existsSync()) {
    print(".env file not found at ${envFile.path}, skip updating!");
    return;
  }

  // Parse SDK_VERSION from .env file
  final envContent = envFile.readAsStringSync();
  final match = RegExp(r'^SDK_VERSION=(.+)$', multiLine: true).firstMatch(envContent);
  final sdkVersion = match?.group(1)?.trim() ?? '';

  if (sdkVersion.isEmpty) {
    print(".env file doesn't contain an SDK_VERSION value, skip updating!");
    return;
  }

  String pubspecContent = pubspecFile.readAsStringSync();

  String newDependency = 'customer_io: $sdkVersion';
  RegExp regex = RegExp(
    r'customer_io:\s*\n\s*path:\s*.*',
    multiLine: true,
  );
  pubspecContent = pubspecContent.replaceAll(regex, newDependency);

  pubspecFile.writeAsStringSync(pubspecContent);

  print("Successfully updated customer_io dependency: ($sdkVersion)");
}
