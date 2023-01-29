import 'dart:async';

import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_inapp.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
  StreamSubscription subscribeToInAppMessages(
      void Function(InAppEvent p1) onEvent) {
    // TODO: implement subscribeToInAppMessages
    throw UnimplementedError();
  }
}

void main() {
  final CustomerIOPlatform initialPlatform = CustomerIOPlatform.instance;

  test('$CustomerIOMethodChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<CustomerIOMethodChannel>());
  });
}
