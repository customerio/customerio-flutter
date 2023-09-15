import 'dart:async' show Future;

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_plugin_version.dart'
    as customer_io_plugin_version;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/config.dart';
import 'utils/logs.dart';

/// This class is added for sample app any may not be required
/// Please feel free to place sdk related code wherever suits best for your app architecture
/// But please make sure to initialize Customer.io SDK only once from your app for
/// better performance and to avoid any unexpected behavior

/// Customer.io SDK repository class to communicate with the SDK.
class CustomerIOSDK extends ChangeNotifier {
  CustomerIOSDKConfig? _sdkConfig;

  CustomerIOSDKConfig? get sdkConfig => _sdkConfig;

  @override
  bool operator ==(Object other) =>
      other is CustomerIOSDK && other._sdkConfig == _sdkConfig;

  @override
  int get hashCode => _sdkConfig?.hashCode ?? 0;

  @override
  void dispose() {
    CustomerIOSDKInstance.dispose();
    super.dispose();
  }

  void onConfigStateChanged(CustomerIOSDKConfig config) {
    _sdkConfig = config;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      await _loadSDKConfig();

      final CioLogLevel logLevel;
      if (_sdkConfig?.debugModeEnabled == false) {
        logLevel = CioLogLevel.error;
      } else {
        logLevel = CioLogLevel.debug;
      }
      return CustomerIO.initialize(
        config: CustomerIOConfig(
          siteId: _sdkConfig?.siteId ?? '',
          apiKey: _sdkConfig?.apiKey ?? '',
          enableInApp: true,
          region: Region.us,
          //config options go here
          trackingApiUrl: _sdkConfig?.trackingUrl ?? '',
          autoTrackDeviceAttributes:
              _sdkConfig?.deviceAttributesTrackingEnabled ?? true,
          autoTrackPushEvents: true,
          backgroundQueueMinNumberOfTasks:
              _sdkConfig?.backgroundQueueMinNumOfTasks ?? 10,
          backgroundQueueSecondsDelay:
              _sdkConfig?.backgroundQueueSecondsDelay ?? 30.0,
          logLevel: logLevel,
        ),
      );
    } catch (ex) {
      return Future.error(ex);
    }
  }
}

/// Customer.io SDK repository scope manager
class CustomerIOSDKScope extends InheritedNotifier<CustomerIOSDK> {
  const CustomerIOSDKScope({
    required super.notifier,
    required super.child,
    super.key,
  });
}

/// Customer.io SDK repository instance manager
class CustomerIOSDKInstance {
  final CustomerIOSDK sdk;

  CustomerIOSDKInstance._newInstance(this.sdk) {
    _instance = this;
  }

  factory CustomerIOSDKInstance._get() {
    return _instance ?? CustomerIOSDKInstance._newInstance(CustomerIOSDK());
  }

  static CustomerIOSDKInstance? _instance;

  static CustomerIOSDK get() {
    return CustomerIOSDKInstance._get().sdk;
  }

  static dispose() => _instance = null;
}

/// Ami App extensions to communicate directly with Customer.io SDK.
/// This is only for testing using sample apps and may not be required by most
/// of the customer apps.
extension AmiAppSDKExtensions on CustomerIOSDK {
  Future<String?> getBuildInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return 'Customer.io'
          ' Flutter SDK ${customer_io_plugin_version.version}'
          ' ${packageInfo.appName}'
          ' ${packageInfo.version} (${packageInfo.buildNumber})';
    } on PlatformException catch (ex) {
      debugError("Failed to get build info: '${ex.message}'", error: ex);
      return null;
    }
  }

  Future<String?> getDeviceToken() async {
    return null;
  }
}

/// Customer.io SDK extensions to save/retrieve configurations to/from preferences.
/// This is only for testing using sample apps and may not be required by most
/// of the customer apps.
extension CustomerIOSDKExtensions on CustomerIOSDK {
  Future<bool> saveConfigToPreferences(CustomerIOSDKConfig config) =>
      SharedPreferences.getInstance()
          .then((prefs) => prefs.saveSDKConfigState(config))
          .then((value) {
        onConfigStateChanged(config);
        return value;
      });

  CustomerIOSDKConfig? getDefaultConfig() => _getEnvironmentConfig();

  CustomerIOSDKConfig? _getEnvironmentConfig() {
    CustomerIOSDKConfig? config;
    try {
      if (dotenv.env.isNotEmpty) {
        config = CustomerIOSDKConfig.fromEnv();
      } else {
        debugLog(
            'No env file found, dotenv initialization: ${dotenv.isInitialized}');
      }
    } catch (ex, s) {
      debugError(
        'Unable to load Customer.io config from env',
        error: ex,
        stackTrace: s,
      );
    }
    return config;
  }

  Future<CustomerIOSDKConfig?> _loadConfigFromPreferences() async {
    return SharedPreferences.getInstance().then((prefs) async {
      try {
        return CustomerIOSDKConfig.fromPrefs(prefs);
      } catch (ex) {
        if (ex is! ArgumentError) {
          debugError("Error loading config from preferences: '$ex'", error: ex);
        }
        return null;
      }
    });
  }

  Future<void> _loadSDKConfig() async {
    if (_sdkConfig != null) {
      debugLog('Customer.io SDK config already initialized, reinitializing');
    }
    final prefsConfig = await _loadConfigFromPreferences();
    if (prefsConfig != null) {
      _sdkConfig = prefsConfig;
      debugLog('Customer.io SDK config loaded from preferences successfully');
    } else {
      final envConfig = _getEnvironmentConfig();
      if (envConfig != null) {
        _sdkConfig = envConfig;
        debugLog('Customer.io SDK config loaded from environment successfully');
      } else {
        debugLog('Customer.io SDK config could not be fetched');
        return Future.error(Exception(
            'No values found for Customer.io SDK in preferences or environment'));
      }
    }
  }
}
