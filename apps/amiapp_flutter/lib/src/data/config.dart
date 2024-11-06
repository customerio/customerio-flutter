import 'package:customer_io/config/in_app_config.dart';
import 'package:customer_io/config/push_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerIOSDKConfig {
  final String cdpApiKey;
  final String? migrationSiteId;
  final Region? region;
  final bool? debugModeEnabled;
  final bool? screenTrackingEnabled;
  final bool? autoTrackDeviceAttributes;
  final String? apiHost;
  final String? cdnHost;
  final int? flushAt;
  final int? flushInterval;
  final InAppConfig? inAppConfig;
  final PushConfig pushConfig;

  CustomerIOSDKConfig({
    required this.cdpApiKey,
    this.migrationSiteId,
    this.region,
    this.debugModeEnabled,
    this.screenTrackingEnabled,
    this.autoTrackDeviceAttributes,
    this.apiHost,
    this.cdnHost,
    this.flushAt,
    this.flushInterval,
    this.inAppConfig,
    PushConfig? pushConfig,
  }) : pushConfig = pushConfig ?? PushConfig();

  factory CustomerIOSDKConfig.fromEnv() =>
      CustomerIOSDKConfig(
        cdpApiKey: dotenv.env[_PreferencesKey.cdpApiKey]!,
        migrationSiteId: dotenv.env[_PreferencesKey.migrationSiteId],
      );

  factory CustomerIOSDKConfig.fromPrefs(SharedPreferences prefs) {
    final cdpApiKey = prefs.getString(_PreferencesKey.cdpApiKey);

    if (cdpApiKey == null) {
      throw ArgumentError('cdpApiKey cannot be null');
    }

    return CustomerIOSDKConfig(
      cdpApiKey: cdpApiKey,
      migrationSiteId: prefs.getString(_PreferencesKey.migrationSiteId),
      region: prefs.getString(_PreferencesKey.region) != null
          ? Region.values.firstWhere(
              (e) => e.name == prefs.getString(_PreferencesKey.region))
          : null,
      debugModeEnabled: prefs.getBool(_PreferencesKey.debugModeEnabled) !=
          false,
      screenTrackingEnabled: prefs.getBool(
          _PreferencesKey.screenTrackingEnabled) != false,
      autoTrackDeviceAttributes:
      prefs.getBool(_PreferencesKey.autoTrackDeviceAttributes),
      apiHost: prefs.getString(_PreferencesKey.apiHost),
      cdnHost: prefs.getString(_PreferencesKey.cdnHost),
      flushAt: prefs.getInt(_PreferencesKey.flushAt),
      flushInterval: prefs.getInt(_PreferencesKey.flushInterval),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cdpApiKey': cdpApiKey,
      'migrationSiteId': migrationSiteId,
      'region': region?.name,
      'logLevel': debugModeEnabled,
      'screenTrackingEnabled': screenTrackingEnabled,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'apiHost': apiHost,
      'cdnHost': cdnHost,
      'flushAt': flushAt,
      'flushInterval': flushInterval,
      'inAppConfig': inAppConfig?.toMap(),
      'pushConfig': pushConfig.toMap(),
    };
  }
}

extension ConfigurationPreferencesExtensions on SharedPreferences {
  Future<bool> setOrRemoveString(String key, String? value) {
    return value != null && value.isNotEmpty
        ? setString(key, value)
        : remove(key);
  }

  Future<bool> setOrRemoveInt(String key, int? value) {
    return value != null ? setInt(key, value) : remove(key);
  }

  Future<bool> setOrRemoveBool(String key, bool? value) {
    return value != null ? setBool(key, value) : remove(key);
  }

  Future<bool> saveSDKConfigState(CustomerIOSDKConfig config) async {
    bool result = true;
    result = result &&
        await setOrRemoveString(_PreferencesKey.cdpApiKey, config.cdpApiKey);
    result = result &&
        await setOrRemoveString(
            _PreferencesKey.migrationSiteId, config.migrationSiteId);
    result = result &&
        await setOrRemoveString(_PreferencesKey.region, config.region?.name);
    result = result &&
        await setOrRemoveBool(
            _PreferencesKey.debugModeEnabled, config.debugModeEnabled);
    result = result &&
        await setOrRemoveBool(_PreferencesKey.autoTrackDeviceAttributes,
            config.autoTrackDeviceAttributes);
    result = result &&
        await setOrRemoveBool(
            _PreferencesKey.screenTrackingEnabled, config.screenTrackingEnabled);
    result = result &&
        await setOrRemoveString(_PreferencesKey.apiHost, config.apiHost);
    result = result &&
        await setOrRemoveString(_PreferencesKey.cdnHost, config.cdnHost);
    result =
        result && await setOrRemoveInt(_PreferencesKey.flushAt, config.flushAt);
    result = result &&
        await setOrRemoveInt(
            _PreferencesKey.flushInterval, config.flushInterval);
    return result;
  }
}

class _PreferencesKey {
  static const cdpApiKey = 'CDP_API_KEY';
  static const migrationSiteId = 'SITE_ID';
  static const region = 'REGION';
  static const debugModeEnabled = 'DEBUG_MODE';
  static const screenTrackingEnabled = 'SCREEN_TRACKING';
  static const autoTrackDeviceAttributes = 'AUTO_TRACK_DEVICE_ATTRIBUTES';
  static const apiHost = 'API_HOST';
  static const cdnHost = 'CDN_HOST';
  static const flushAt = 'FLUSH_AT';
  static const flushInterval = 'FLUSH_INTERVAL';
}
