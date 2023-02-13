import 'dart:async';

import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_inapp.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

///The MockCustomerIoPlatform class is a mock implementation of the CustomerIOPlatform interface.
/// It provides stubbed implementations of all the methods defined in the CustomerIOPlatform interface,
/// which are intended to be overridden in tests. The purpose of this class is to simulate the behavior
/// of the actual platform implementation, so that tests can run without making actual calls to the platform,
class MockCustomerIoPlatform
    with MockPlatformInterfaceMixin
    implements CustomerIOPlatform {
  @override
  Future<void> initialize({required CustomerIOConfig config}) {
    // TODO: implement config
    throw UnimplementedError();
  }

  @override
  void clearIdentify() {
    // TODO: implement clearIdentify
  }

  @override
  void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    // TODO: implement identify
  }

  @override
  void screen(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    // TODO: implement screen
  }

  @override
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    // TODO: implement setDeviceAttributes
  }

  @override
  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    // TODO: implement setProfileAttributes
  }

  @override
  void track(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    // TODO: implement track
  }

  @override
  StreamSubscription subscribeToInAppEventListener(
      void Function(InAppEvent p1) onEvent) {
    // TODO: implement subscribeToInAppEventListener
    throw UnimplementedError();
  }

  @override
  void registerDeviceToken({required String deviceToken}) {
    // TODO: implement registerDeviceToken
  }

  @override
  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    // TODO: implement trackMetric
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final CustomerIOPlatform initialPlatform = CustomerIOPlatform.instance;

  test('$CustomerIOMethodChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<CustomerIOMethodChannel>());
  });
}
