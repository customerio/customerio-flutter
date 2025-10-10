import 'package:customer_io/config/customer_io_config.dart';
import 'package:customer_io/config/in_app_config.dart';
import 'package:customer_io/config/push_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_plugin_version.dart' as plugin_info;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerIOConfig', () {
    test('should initialize with required parameters and default values', () {
      final config = CustomerIOConfig(cdpApiKey: 'testApiKey');

      expect(config.cdpApiKey, 'testApiKey');
      expect(config.jsKey, isNull);
      expect(config.migrationSiteId, isNull);
      expect(config.region, isNull);
      expect(config.logLevel, isNull);
      expect(config.autoTrackDeviceAttributes, isNull);
      expect(config.apiHost, isNull);
      expect(config.cdnHost, isNull);
      expect(config.flushAt, isNull);
      expect(config.flushInterval, isNull);
      expect(config.screenViewUse, isNull);

      expect(config.inAppConfig, isNull);

      final pushConfig = config.pushConfig;
      expect(pushConfig, isNotNull);
      final pushConfigAndroid = pushConfig.pushConfigAndroid;
      expect(pushConfigAndroid, isNotNull);
      expect(pushConfigAndroid.pushClickBehavior,
          PushClickBehaviorAndroid.activityPreventRestart);

      expect(config.source, 'Flutter');
      expect(config.version, plugin_info.version);
    });

    test('should initialize with all parameters', () {
      final inAppConfig = InAppConfig(siteId: 'testSiteId');
      final pushConfig = PushConfig(
          android: PushConfigAndroid(
              pushClickBehavior:
                  PushClickBehaviorAndroid.activityPreventRestart));

      final config = CustomerIOConfig(
        cdpApiKey: 'testApiKey',
        jsKey: 'webKey',
        migrationSiteId: 'testMigrationSiteId',
        region: Region.us,
        logLevel: CioLogLevel.debug,
        autoTrackDeviceAttributes: true,
        apiHost: 'https://api.example.com',
        cdnHost: 'https://cdn.example.com',
        flushAt: 15,
        flushInterval: 45,
        screenViewUse: ScreenView.all,
        inAppConfig: inAppConfig,
        pushConfig: pushConfig,
      );

      expect(config.cdpApiKey, 'testApiKey');
      expect(config.jsKey, 'webKey');
      expect(config.migrationSiteId, 'testMigrationSiteId');
      expect(config.region, Region.us);
      expect(config.logLevel, CioLogLevel.debug);
      expect(config.autoTrackDeviceAttributes, isTrue);
      expect(config.apiHost, 'https://api.example.com');
      expect(config.cdnHost, 'https://cdn.example.com');
      expect(config.flushAt, 15);
      expect(config.flushInterval, 45);
      expect(config.screenViewUse, ScreenView.all);
      expect(config.inAppConfig, inAppConfig);
      expect(config.pushConfig, pushConfig);
      expect(config.source, 'Flutter');
      expect(config.version, plugin_info.version);
    });

    test('should return correct map from toMap()', () {
      final inAppConfig = InAppConfig(siteId: 'testSiteId');
      final pushConfig = PushConfig(
          android: PushConfigAndroid(
              pushClickBehavior:
                  PushClickBehaviorAndroid.activityPreventRestart));

      final config = CustomerIOConfig(
        cdpApiKey: 'testApiKey',
        jsKey: 'webKey',
        migrationSiteId: 'testMigrationSiteId',
        region: Region.eu,
        logLevel: CioLogLevel.info,
        autoTrackDeviceAttributes: false,
        trackApplicationLifecycleEvents: false,
        apiHost: 'https://api.example.com',
        cdnHost: 'https://cdn.example.com',
        flushAt: 25,
        flushInterval: 55,
        screenViewUse: ScreenView.inApp,
        inAppConfig: inAppConfig,
        pushConfig: pushConfig,
      );

      final expectedMap = {
        'cdpApiKey': 'testApiKey',
        'migrationSiteId': 'testMigrationSiteId',
        'jsKey': 'webKey',
        'region': 'eu',
        'logLevel': 'info',
        'autoTrackDeviceAttributes': false,
        'trackApplicationLifecycleEvents': false,
        'apiHost': 'https://api.example.com',
        'cdnHost': 'https://cdn.example.com',
        'flushAt': 25,
        'flushInterval': 55,
        'screenViewUse': 'inApp',
        'inApp': inAppConfig.toMap(),
        'push': pushConfig.toMap(),
        'version': config.version,
        'source': config.source,
      };

      expect(config.toMap(), expectedMap);
    });

    test('should initialize default pushConfig when not provided', () {
      final config = CustomerIOConfig(cdpApiKey: 'testApiKey');

      expect(config.pushConfig.pushConfigAndroid.pushClickBehavior,
          PushClickBehaviorAndroid.activityPreventRestart);
    });

    test('toMap() omits jsKey when not provided', () {
      final config = CustomerIOConfig(cdpApiKey: 'testApiKey');

      final map = config.toMap();
      expect(map.containsKey('jsKey'), isFalse);
    });
  });

  group('CustomerIOConfig with Region', () {
    for (var region in Region.values) {
      test('should initialize with region $region and verify map value', () {
        final config = CustomerIOConfig(
          cdpApiKey: 'testApiKey',
          region: region,
        );

        // Check initialization value
        expect(config.region, region);

        // Verify only the region entry in toMap output
        final map = config.toMap();
        expect(map['region'], region.name);
      });
    }
  });

  group('CustomerIOConfig with LogLevel', () {
    for (var logLevel in CioLogLevel.values) {
      test('should initialize with log level $logLevel and verify map value',
          () {
        final config = CustomerIOConfig(
          cdpApiKey: 'testApiKey',
          logLevel: logLevel,
        );

        // Check initialization value
        expect(config.logLevel, logLevel);

        // Verify only the logLevel entry in toMap output
        final map = config.toMap();
        expect(map['logLevel'], logLevel.name);
      });
    }
  });

  group('InAppConfig', () {
    test('should return correct map from toMap()', () {
      final inAppConfig = InAppConfig(siteId: 'testSiteId');
      final expectedMap = {'siteId': 'testSiteId'};

      expect(inAppConfig.toMap(), expectedMap);
    });
  });

  group('PushConfig', () {
    test('should initialize with default PushConfigAndroid', () {
      final pushConfig = PushConfig();

      expect(pushConfig.pushConfigAndroid, isNotNull);
      expect(pushConfig.pushConfigAndroid.pushClickBehavior,
          PushClickBehaviorAndroid.activityPreventRestart);
    });

    test('should return correct map from toMap()', () {
      final pushConfig = PushConfig(
        android: PushConfigAndroid(
          pushClickBehavior: PushClickBehaviorAndroid.activityNoFlags,
        ),
      );

      final expectedMap = {
        'android': {
          'pushClickBehavior': 'ACTIVITY_NO_FLAGS',
        },
      };

      expect(pushConfig.toMap(), expectedMap);
    });
  });

  group('PushConfigAndroid with PushClickBehaviorAndroid', () {
    for (var pushClickBehavior in PushClickBehaviorAndroid.values) {
      test(
          'should initialize with pushConfigAndroid $pushClickBehavior and verify map value',
          () {
        final config = PushConfigAndroid(
          pushClickBehavior: pushClickBehavior,
        );

        // Check initialization value
        expect(config.pushClickBehavior, pushClickBehavior);

        // Verify only the logLevel entry in toMap output
        final map = config.toMap();
        expect(map['pushClickBehavior'], pushClickBehavior.rawValue);
      });
    }
  });
}
