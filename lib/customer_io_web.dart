import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:js/js.dart';

import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/data_pipelines/customer_io_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS('window')
external JSObject get _window;

@JS('Function')
external Object _jsFunctionConstructor(String code);

class CustomerIOWebPlugin extends CustomerIOPlatform {
  String? _currentUserId;
  late final CustomerIOConfig _config;

  static void registerWith(Registrar registrar) {
    CustomerIOPlatform.instance = CustomerIOWebPlugin();
  }

  void _injectAnalyticsSnippet(String key) {
    try {
      final has = _window.has('cioanalytics');
      if (has) return;
    } catch (_) {}

    final snippet = '''
      !(function () {
        var i = "cioanalytics",
          analytics = (window[i] = window[i] || []);
        if (!analytics.initialize)
          if (analytics.invoked)
            window.console &&
              console.error &&
              console.error("Snippet included twice.");
          else {
            analytics.invoked = !0;
            analytics.methods = [
              "trackSubmit",
              "trackClick",
              "trackLink",
              "trackForm",
              "pageview",
              "identify",
              "reset",
              "group",
              "track",
              "ready",
              "alias",
              "debug",
              "page",
              "once",
              "off",
              "on",
              "addSourceMiddleware",
              "addIntegrationMiddleware",
              "setAnonymousId",
              "addDestinationMiddleware",
            ];
            analytics.factory = function (e) {
              return function () {
                var t = Array.prototype.slice.call(arguments);
                t.unshift(e);
                analytics.push(t);
                return analytics;
              };
            };
            for (var e = 0; e < analytics.methods.length; e++) {
              var key = analytics.methods[e];
              analytics[key] = analytics.factory(key);
            }
            analytics.load = function (key, e) {
              var t = document.createElement("script");
              t.type = "text/javascript";
              t.async = !0;
              t.setAttribute("data-global-customerio-analytics-key", i);
              t.src =
                "https://cdp.customer.io/v1/analytics-js/snippet/" +
                key +
                "/analytics.min.js";
              var n = document.getElementsByTagName("script")[0];
              n.parentNode.insertBefore(t, n);
              analytics._writeKey = key;
              analytics._loadOptions = e;
            };
            analytics.SNIPPET_VERSION = "4.15.3";
            analytics.load("$key");
          }
      })();
    ''';

    try {
      final fn = _jsFunctionConstructor(snippet) as Function;
      fn();
    } catch (_) {
      print('CustomerIO web: Failed to inject analytics snippet.');
    }
  }

  JSObject get _cio {
    if (!_window.has('cioanalytics')) {
      _window['cioanalytics'] = <JSAny?>[].toJS;
    }
    return _window['cioanalytics'] as JSObject;
  }

  JSAny? _toJS(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.toJS;
    if (value is num) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is List) {
      return value.map(_toJS).toList().toJS;
    }
    if (value is Map<String, dynamic>) {
      final jsObject = JSObject();
      value.forEach((key, val) {
        jsObject[key] = _toJS(val);
      });
      return jsObject;
    }
    return value.toString().toJS;
  }

  void _callCio(String method, [List<dynamic>? args]) {
    final List<JSAny?> payload = [method.toJS];
    if (args != null && args.isNotEmpty) {
      payload.addAll(args.map(_toJS));
    }

    _cio.callMethod('push'.toJS, payload.toJS);
  }

  @override
  Future<void> initialize({required CustomerIOConfig config}) async {
    _config = config;
    final key = _config.jsKey ?? '';
    if (key.isEmpty) {
      print(
          'CustomerIO web: JSKey is empty. Do NOT use cdpApiKey in client-side code.');
    }
    _injectAnalyticsSnippet(key);
  }

  @override
  void identify(
      {required String userId, Map<String, dynamic> traits = const {}}) {
    _currentUserId = userId;

    if (traits.isEmpty) {
      _callCio('identify', [userId]);
    } else {
      _callCio('identify', [userId, traits]);
    }
  }

  @override
  void clearIdentify() {
    _currentUserId = null;
    _callCio('reset', const []);
  }

  @override
  void track(
      {required String name, Map<String, dynamic> properties = const {}}) {
    if (properties.isEmpty) {
      _callCio('track', [name]);
    } else {
      _callCio('track', [name, properties]);
    }
  }

  @override
  void screen(
      {required String title, Map<String, dynamic> properties = const {}}) {
    if (properties.isEmpty) {
      _callCio('page', [title]);
    } else {
      _callCio('page', [title, properties]);
    }
  }

  @override
  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {}

  @override
  void deleteDeviceToken() {}

  @override
  void registerDeviceToken({required String deviceToken}) {}

  @override
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    if (_currentUserId != null) {
      identify(userId: _currentUserId!, traits: attributes);
    }
  }

  @override
  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    if (_currentUserId != null) {
      identify(userId: _currentUserId!, traits: attributes);
    }
  }
}
