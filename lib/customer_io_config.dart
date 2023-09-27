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
  AndroidPushClickBehavior androidPushClickBehavior;

  bool enableInApp;

  String version;

  CustomerIOConfig(
      {required this.siteId,
      required this.apiKey,
      this.region = Region.us,
      @Deprecated("organizationId is deprecated and isn't required anymore, use enableInApp instead. This field will be removed in the next release.")
          this.organizationId = "",
      this.logLevel = CioLogLevel.debug,
      this.autoTrackDeviceAttributes = true,
      this.trackingApiUrl = "",
      this.autoTrackPushEvents = true,
      this.backgroundQueueMinNumberOfTasks = 10,
      this.backgroundQueueSecondsDelay = 30.0,
      this.androidPushClickBehavior = AndroidPushClickBehavior.activityPreventRestart,
      this.enableInApp = false,
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
      'androidPushClickBehavior': androidPushClickBehavior.rawValue,
      'enableInApp': enableInApp,
      'version': version,
      'source': "Flutter"
    };
  }
}
