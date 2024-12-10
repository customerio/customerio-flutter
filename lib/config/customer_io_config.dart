import '../customer_io_enums.dart';
import '../customer_io_plugin_version.dart' as plugin_info show version;
import 'in_app_config.dart';
import 'push_config.dart';

class CustomerIOConfig {
  final String source = 'Flutter';
  final String version = plugin_info.version;

  final String cdpApiKey;
  final String? migrationSiteId;
  final Region? region;
  final CioLogLevel? logLevel;
  final bool? trackApplicationLifecycleEvents;
  final bool? autoTrackDeviceAttributes;
  final String? apiHost;
  final String? cdnHost;
  final int? flushAt;
  final int? flushInterval;
  final InAppConfig? inAppConfig;
  final PushConfig pushConfig;

  CustomerIOConfig({
    required this.cdpApiKey,
    this.migrationSiteId,
    this.region,
    this.logLevel,
    this.autoTrackDeviceAttributes,
    this.trackApplicationLifecycleEvents,
    this.apiHost,
    this.cdnHost,
    this.flushAt,
    this.flushInterval,
    this.inAppConfig,
    PushConfig? pushConfig,
  }) : pushConfig = pushConfig ?? PushConfig();

  Map<String, dynamic> toMap() {
    return {
      'cdpApiKey': cdpApiKey,
      'migrationSiteId': migrationSiteId,
      'region': region?.name,
      'logLevel': logLevel?.name,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'trackApplicationLifecycleEvents': trackApplicationLifecycleEvents,
      'apiHost': apiHost,
      'cdnHost': cdnHost,
      'flushAt': flushAt,
      'flushInterval': flushInterval,
      'inApp': inAppConfig?.toMap(),
      'push': pushConfig.toMap(),
      'version': version,
      'source': source
    };
  }
}
