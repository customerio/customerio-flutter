import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// This is more of test of what our Native platform is expecting.
void main() {
  const MethodChannel channel = MethodChannel('customer_io');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return Future
              .value(); // Simulate a successful response from the platform.
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('initialize should call platform method', () async {
    final customerIO = CustomerIOMethodChannel();
    final config = CustomerIOConfig(siteId: 'site_id', apiKey: 'api_key');
    await customerIO.initialize(config: config);
  });
}
