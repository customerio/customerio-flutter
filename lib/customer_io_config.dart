import 'customer_io_enums.dart';

/// Configure plugin using CustomerIOConfig
class CustomerIOConfig {
  final String siteId;
  final String apiKey;
  Region region;
  String organizationId;

  CioLogLevel logLevel;
  bool autoTrackDeviceAttributes;
  String trackingApiUrl;
  bool autoTrackPushEvents;
  int backgroundQueueMinNumberOfTasks;
  double backgroundQueueSecondsDelay;

  String version;

  CustomerIOConfig(
      {required this.siteId,
      required this.apiKey,
      this.region = Region.us,
      this.organizationId = "",
      this.logLevel = CioLogLevel.debug,
      this.autoTrackDeviceAttributes = true,
      this.trackingApiUrl = "",
      this.autoTrackPushEvents = true,
      this.backgroundQueueMinNumberOfTasks = 10,
      this.backgroundQueueSecondsDelay = 30.0,
      this.version = ""});

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      'apiKey': apiKey,
      'region': region.name,
      'organizationId': organizationId,
      'logLevel': logLevel.name,
      'autoTrackDeviceAttributes': autoTrackDeviceAttributes,
      'trackingApiUrl': trackingApiUrl,
      'autoTrackPushEvents': autoTrackPushEvents,
      'backgroundQueueMinNumberOfTasks': backgroundQueueMinNumberOfTasks,
      'backgroundQueueSecondsDelay': backgroundQueueSecondsDelay,
      'version': version,
    };
  }
}
