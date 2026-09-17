import 'package:customer_io/config/in_app_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/messaging_in_app/method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the Dart half of the in-app color scheme override, by both routes it can travel: the
/// `inApp` configuration read at initialization, and the runtime setter.
///
/// The native SDKs do the real work — each resolves the scheme and re-themes messages already on
/// screen, inline views included. What Dart owns is the wire contract, and that is what these
/// pin: both native layers match `auto`/`light`/`dark` lowercase and iOS's config parser resolves
/// anything else to `.auto`, so a re-cased or renamed value renders the device's theme instead of
/// the app's — a styling bug with no error attached.
///
/// They do NOT pin the native key name: renaming `colorScheme` in either bridge leaves these
/// green while the override stops arriving.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CioColorScheme', () {
    test('serializes every member to the value both native SDKs match', () {
      // Asserted literally rather than through the enum: renaming a member is safe, changing one
      // of these strings silently breaks the override on both platforms.
      expect(CioColorScheme.auto.rawValue, 'auto');
      expect(CioColorScheme.light.rawValue, 'light');
      expect(CioColorScheme.dark.rawValue, 'dark');
    });
  });

  group('InAppConfig', () {
    test('serializes the scheme under the key the native parsers read', () {
      final config = InAppConfig(
        siteId: 'testSiteId',
        colorScheme: CioColorScheme.dark,
      );

      expect(config.toMap(), {'siteId': 'testSiteId', 'colorScheme': 'dark'});
    });

    test('omits the scheme when the app configures none', () {
      final config = InAppConfig(siteId: 'testSiteId');

      // Absent rather than 'auto': the native SDKs already default to AUTO, and sending a value
      // the host never set would make "follow the device" indistinguishable from an explicit
      // choice.
      expect(config.toMap(), {'siteId': 'testSiteId'});
    });
  });

  group('setColorScheme', () {
    late CustomerIOMessagingInAppMethodChannel platform;
    late List<MethodCall> nativeCalls;

    setUp(() {
      nativeCalls = [];
      platform = CustomerIOMessagingInAppMethodChannel();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (call) async {
        nativeCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('sends the scheme to native as its wire value', () {
      platform.setColorScheme(CioColorScheme.light);

      expect(nativeCalls, hasLength(1));
      expect(nativeCalls.single.method, 'setColorScheme');
      expect(nativeCalls.single.arguments, {'colorScheme': 'light'});
    });

    test('can return to following the device appearance', () {
      platform.setColorScheme(CioColorScheme.auto);

      expect(nativeCalls.single.arguments, {'colorScheme': 'auto'});
    });
  });
}
