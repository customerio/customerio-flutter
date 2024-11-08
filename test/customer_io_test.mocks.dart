// Mocks generated by Mockito 5.3.2 from annotations
// in customer_io/example/ios/.symlinks/plugins/customer_io/test/customer_io_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i2;

import 'package:customer_io/customer_io_config.dart' as _i4;
import 'package:customer_io/customer_io_enums.dart' as _i5;
import 'package:customer_io/customer_io_inapp.dart' as _i6;
import 'package:mockito/mockito.dart' as _i1;

import 'customer_io_test.dart' as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeStreamSubscription_0<T> extends _i1.SmartFake
    implements _i2.StreamSubscription<T> {
  _FakeStreamSubscription_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [TestCustomerIoPlatform].
///
/// See the documentation for Mockito's code generation for more information.
class MockTestCustomerIoPlatform extends _i1.Mock
    implements _i3.TestCustomerIoPlatform {
  MockTestCustomerIoPlatform() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.Future<void> initialize({required _i4.CustomerIOConfig? config}) =>
      (super.noSuchMethod(
        Invocation.method(
          #initialize,
          [],
          {#config: config},
        ),
        returnValue: _i2.Future<void>.value(),
        returnValueForMissingStub: _i2.Future<void>.value(),
      ) as _i2.Future<void>);
  @override
  void identify({
    required String? userId,
    Map<String, dynamic>? traits = const {},
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #identify,
          [],
          {
            #userId: userId,
            #traits: traits,
          },
        ),
        returnValueForMissingStub: null,
      );
  @override
  void clearIdentify() => super.noSuchMethod(
        Invocation.method(
          #clearIdentify,
          [],
        ),
        returnValueForMissingStub: null,
      );
  @override
  void track({
    required String? name,
    Map<String, dynamic>? properties = const {},
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #track,
          [],
          {
            #name: name,
            #properties: properties,
          },
        ),
        returnValueForMissingStub: null,
      );
  @override
  void trackMetric({
    required String? deliveryID,
    required String? deviceToken,
    required _i5.MetricEvent? event,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #trackMetric,
          [],
          {
            #deliveryID: deliveryID,
            #deviceToken: deviceToken,
            #event: event,
          },
        ),
        returnValueForMissingStub: null,
      );
  @override
  void registerDeviceToken({required String? deviceToken}) =>
      super.noSuchMethod(
        Invocation.method(
          #registerDeviceToken,
          [],
          {#deviceToken: deviceToken},
        ),
        returnValueForMissingStub: null,
      );
  @override
  void screen({
    required String? title,
    Map<String, dynamic>? properties = const {},
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #screen,
          [],
          {
            #title: title,
            #properties: properties,
          },
        ),
        returnValueForMissingStub: null,
      );
  @override
  void setDeviceAttributes({required Map<String, dynamic>? attributes}) =>
      super.noSuchMethod(
        Invocation.method(
          #setDeviceAttributes,
          [],
          {#attributes: attributes},
        ),
        returnValueForMissingStub: null,
      );
  @override
  void setProfileAttributes({required Map<String, dynamic>? traits}) =>
      super.noSuchMethod(
        Invocation.method(
          #setProfileAttributes,
          [],
          {#traits: traits},
        ),
        returnValueForMissingStub: null,
      );
  @override
  _i2.StreamSubscription<dynamic> subscribeToInAppEventListener(
          void Function(_i6.InAppEvent)? onEvent) =>
      (super.noSuchMethod(
        Invocation.method(
          #subscribeToInAppEventListener,
          [onEvent],
        ),
        returnValue: _FakeStreamSubscription_0<dynamic>(
          this,
          Invocation.method(
            #subscribeToInAppEventListener,
            [onEvent],
          ),
        ),
      ) as _i2.StreamSubscription<dynamic>);
}
