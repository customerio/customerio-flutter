import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

///The MockCustomerIoPlatform class is a mock implementation of the CustomerIOPlatform interface.
/// It provides stubbed implementations of all the methods defined in the CustomerIOPlatform interface,
/// which are intended to be overridden in tests. The purpose of this class is to simulate the behavior
/// of the actual platform implementation, so that tests can run without making actual calls to the platform,
class MockCustomerIoPlatform extends Mock
    with MockPlatformInterfaceMixin  implements CustomerIOPlatform{ }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  group('CustomerIO', () {
    late MockCustomerIoPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockCustomerIoPlatform();
      CustomerIOPlatform.instance = mockPlatform;
    });

    test('initialize() calls platform', () async {
      final config = CustomerIOConfig(siteId: '123', apiKey: '456');
      when(mockPlatform.initialize(config: config)).thenAnswer((_) => Future.value());
      await CustomerIO.initialize(config: config);
      verify(mockPlatform.initialize(config: config)).called(1);
    });
  });
}
