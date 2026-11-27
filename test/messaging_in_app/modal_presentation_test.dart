import 'package:customer_io/config/in_app_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the Dart half of the Android modal presentation option: the wire values and where
/// they land in the `inApp` configuration map that the Android bridge reads at initialization.
void main() {
  group('ModalPresentationAndroid', () {
    test('serializes every member to the value the Android bridge matches', () {
      // Asserted literally rather than through the enum: changing one of these strings
      // silently drops the option on Android.
      expect(ModalPresentationAndroid.activity.rawValue, 'ACTIVITY');
      expect(ModalPresentationAndroid.hostWindow.rawValue, 'HOST_WINDOW');
    });
  });

  group('InAppConfig android', () {
    test('serializes modal presentation under the android key', () {
      final config = InAppConfig(
        siteId: 'testSiteId',
        android: InAppConfigAndroid(
          modalPresentation: ModalPresentationAndroid.hostWindow,
        ),
      );

      expect(config.toMap(), {
        'siteId': 'testSiteId',
        'android': {'modalPresentation': 'HOST_WINDOW'},
      });
    });

    test('sends an explicit activity choice', () {
      final config = InAppConfig(
        siteId: 'testSiteId',
        android: InAppConfigAndroid(
          modalPresentation: ModalPresentationAndroid.activity,
        ),
      );

      expect(config.toMap()['android'], {'modalPresentation': 'ACTIVITY'});
    });

    test('omits the android key when no android config is given', () {
      final config = InAppConfig(siteId: 'testSiteId');

      expect(config.toMap(), {'siteId': 'testSiteId'});
    });

    test('omits the android key when the android config sets nothing', () {
      final config = InAppConfig(
        siteId: 'testSiteId',
        android: InAppConfigAndroid(),
      );

      expect(InAppConfigAndroid().toMap(), isEmpty);
      expect(config.toMap(), {'siteId': 'testSiteId'});
    });

    test('keeps the other in-app options alongside android', () {
      final config = InAppConfig(
        siteId: 'testSiteId',
        colorScheme: CioColorScheme.dark,
        android: InAppConfigAndroid(
          modalPresentation: ModalPresentationAndroid.hostWindow,
        ),
      );

      expect(config.toMap(), {
        'siteId': 'testSiteId',
        'colorScheme': 'dark',
        'android': {'modalPresentation': 'HOST_WINDOW'},
      });
    });
  });
}
