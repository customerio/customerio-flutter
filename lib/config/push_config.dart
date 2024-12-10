import 'package:customer_io/customer_io_enums.dart';

class PushConfig {
  PushConfigAndroid pushConfigAndroid;

  PushConfig({PushConfigAndroid? android})
      : pushConfigAndroid = android ?? PushConfigAndroid();

  Map<String, dynamic> toMap() {
    return {
      'android': pushConfigAndroid.toMap(),
    };
  }
}

class PushConfigAndroid {
  PushClickBehaviorAndroid pushClickBehavior;

  PushConfigAndroid(
      {this.pushClickBehavior =
          PushClickBehaviorAndroid.activityPreventRestart});

  Map<String, dynamic> toMap() {
    return {
      'pushClickBehavior': pushClickBehavior.rawValue,
    };
  }
}
