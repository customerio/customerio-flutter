import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owned iOS manifests declare the iOS 15 deployment target', () {
    const expectedManifestMarkers = <String, String>{
      'ios/customer_io.podspec': "s.platform = :ios, '15.0'",
      'ios/customer_io/Package.swift': '.iOS("15.0")',
      'ios/customer_io_richpush.podspec': "s.platform = :ios, '15.0'",
    };

    final discoveredManifests = Directory('ios')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((file) => file.path.replaceAll('\\', '/'))
        .where(
          (path) =>
              !path.contains('/Flutter/ephemeral/') &&
              !path.contains('/.build/') &&
              !path.contains('/.swiftpm/') &&
              !path.contains('/Pods/') &&
              !path.contains('/.symlinks/') &&
              (path.endsWith('/Package.swift') || path.endsWith('.podspec')),
        )
        .toSet();

    expect(discoveredManifests, expectedManifestMarkers.keys.toSet());

    for (final entry in expectedManifestMarkers.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        contains(entry.value),
        reason: 'Expected ${entry.key} to declare the iOS 15 deployment target',
      );
    }
  });
}
