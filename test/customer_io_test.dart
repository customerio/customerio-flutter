import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCustomerIoPlatform
    with MockPlatformInterfaceMixin
    implements CustomerIOPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize({required CustomerIOConfig config}) {
    // TODO: implement config
    throw UnimplementedError();
  }

  @override
  void identify(
      {required String identifier, required Map<String, dynamic> attributes}) {
    // TODO: implement identify
  }
}

void main() {
  final CustomerIOPlatform initialPlatform = CustomerIOPlatform.instance;

  test('$CustomerIOMethodChannel is the default instance', () {
    expect(initialPlatform, isInstanceOf<CustomerIOMethodChannel>());
  });

  test('getPlatformVersion', () async {
    MockCustomerIoPlatform fakePlatform = MockCustomerIoPlatform();
    CustomerIOPlatform.instance = fakePlatform;

    expect(await CustomerIo.getPlatformVersion(), '42');
  });
}
