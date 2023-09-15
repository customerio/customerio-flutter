import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerIOSDKConfig {
  String siteId;
  String apiKey;
  String? trackingUrl;
  double? backgroundQueueSecondsDelay;
  int? backgroundQueueMinNumOfTasks;
  bool screenTrackingEnabled;
  bool deviceAttributesTrackingEnabled;
  bool debugModeEnabled;

  CustomerIOSDKConfig({
    required this.siteId,
    required this.apiKey,
    this.trackingUrl = "https://track-sdk.customer.io/",
    this.backgroundQueueSecondsDelay = 30.0,
    this.backgroundQueueMinNumOfTasks = 10,
    this.screenTrackingEnabled = true,
    this.deviceAttributesTrackingEnabled = true,
    this.debugModeEnabled = true,
  });

  factory CustomerIOSDKConfig.fromEnv() => CustomerIOSDKConfig(
      siteId: dotenv.env[_PreferencesKey.siteId]!,
      apiKey: dotenv.env[_PreferencesKey.apiKey]!);

  factory CustomerIOSDKConfig.fromPrefs(SharedPreferences prefs) {
    final siteId = prefs.getString(_PreferencesKey.siteId);
    final apiKey = prefs.getString(_PreferencesKey.apiKey);

    if (siteId == null) {
      throw ArgumentError('siteId cannot be null');
    } else if (apiKey == null) {
      throw ArgumentError('apiKey cannot be null');
    }

    return CustomerIOSDKConfig(
      siteId: siteId,
      apiKey: apiKey,
      trackingUrl: prefs.getString(_PreferencesKey.trackingUrl),
      backgroundQueueSecondsDelay:
          prefs.getDouble(_PreferencesKey.backgroundQueueSecondsDelay),
      backgroundQueueMinNumOfTasks:
          prefs.getInt(_PreferencesKey.backgroundQueueMinNumOfTasks),
      screenTrackingEnabled:
          prefs.getBool(_PreferencesKey.screenTrackingEnabled) != false,
      deviceAttributesTrackingEnabled:
          prefs.getBool(_PreferencesKey.deviceAttributesTrackingEnabled) !=
              false,
      debugModeEnabled:
          prefs.getBool(_PreferencesKey.debugModeEnabled) != false,
    );
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

  Future<bool> setOrRemoveDouble(String key, double? value) {
    return value != null ? setDouble(key, value) : remove(key);
  }

  Future<bool> setOrRemoveBool(String key, bool? value) {
    return value != null ? setBool(key, value) : remove(key);
  }

  Future<bool> saveSDKConfigState(CustomerIOSDKConfig config) async {
    bool result = true;
    result = result &&
        await setOrRemoveString(_PreferencesKey.siteId, config.siteId);
    result = result &&
        await setOrRemoveString(_PreferencesKey.apiKey, config.apiKey);
    result = result &&
        await setOrRemoveString(
            _PreferencesKey.trackingUrl, config.trackingUrl);
    result = result &&
        await setOrRemoveDouble(_PreferencesKey.backgroundQueueSecondsDelay,
            config.backgroundQueueSecondsDelay);
    result = result &&
        await setOrRemoveInt(_PreferencesKey.backgroundQueueMinNumOfTasks,
            config.backgroundQueueMinNumOfTasks);
    result = result &&
        await setOrRemoveBool(_PreferencesKey.screenTrackingEnabled,
            config.screenTrackingEnabled);
    result = result &&
        await setOrRemoveBool(_PreferencesKey.deviceAttributesTrackingEnabled,
            config.deviceAttributesTrackingEnabled);
    result = result &&
        await setOrRemoveBool(
            _PreferencesKey.debugModeEnabled, config.debugModeEnabled);
    return result;
  }
}

class _PreferencesKey {
  static const siteId = 'SITE_ID';
  static const apiKey = 'API_KEY';
  static const trackingUrl = 'TRACKING_URL';
  static const backgroundQueueSecondsDelay = 'BACKGROUND_QUEUE_SECONDS_DELAY';
  static const backgroundQueueMinNumOfTasks =
      'BACKGROUND_QUEUE_MIN_NUMBER_OF_TASKS';
  static const screenTrackingEnabled = 'TRACK_SCREENS';
  static const deviceAttributesTrackingEnabled = 'TRACK_DEVICE_ATTRIBUTES';
  static const debugModeEnabled = 'DEBUG_MODE';
}
