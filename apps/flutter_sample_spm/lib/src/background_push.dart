import 'package:customer_io/customer_io.dart';
import 'package:flutter/foundation.dart';

/// Handles Customer.io silent pushes. On Android this can run in a background
/// isolate the plugin starts, with none of the app's state.
@pragma('vm:entry-point')
void onCustomerIOBackgroundPush(CustomerIOBackgroundPush push) {
  debugPrint('Customer.io silent push ${push.deliveryId}: ${push.data}');
}
