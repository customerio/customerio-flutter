import 'package:flutter_test/flutter_test.dart';
import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCustomerIoPlatform 
    with MockPlatformInterfaceMixin
    implements CustomerIoPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final CustomerIoPlatform initialPlatform = CustomerIoPlatform.instance;

  test('$MethodChannelCustomerIo is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCustomerIo>());
  });

  test('getPlatformVersion', () async {
    CustomerIo customerIoPlugin = CustomerIo();
    MockCustomerIoPlatform fakePlatform = MockCustomerIoPlatform();
    CustomerIoPlatform.instance = fakePlatform;
  
    expect(await customerIoPlugin.getPlatformVersion(), '42');
  });
}
