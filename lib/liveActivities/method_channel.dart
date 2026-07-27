import 'package:flutter/services.dart';

import '_native_constants.dart';
import 'live_activity_payload.dart';
import 'platform_interface.dart';

/// An implementation of [CustomerIOLiveActivitiesPlatform] that uses method channels.
class CustomerIOLiveActivitiesMethodChannel
    extends CustomerIOLiveActivitiesPlatform {
  final MethodChannel methodChannel =
      const MethodChannel('customer_io_live_activities');

  @override
  Future<String> start(LiveActivityPayload payload) async {
    try {
      final result = await methodChannel.invokeMethod<String>(
        NativeMethods.start,
        {NativeMethodParams.payload: payload.toMap()},
      );
      // A null id means the platform reported success without starting anything. Returning '' would
      // hand back an id that looks usable and only fails later, on an update or end that silently
      // matches nothing — fail here instead, where the cause is still visible.
      return result ?? (throw _noActivityId(NativeMethods.start));
    } on MissingPluginException {
      throw _notEnabled();
    }
  }

  @override
  Future<void> update(String activityId, LiveActivityPayload payload) async {
    try {
      await methodChannel.invokeMethod<void>(
        NativeMethods.update,
        {
          NativeMethodParams.activityId: activityId,
          NativeMethodParams.payload: payload.toMap(),
        },
      );
    } on MissingPluginException {
      throw _notEnabled();
    }
  }

  @override
  Future<void> end(String activityId, {LiveActivityPayload? payload}) async {
    try {
      await methodChannel.invokeMethod<void>(
        NativeMethods.end,
        {
          NativeMethodParams.activityId: activityId,
          if (payload != null) NativeMethodParams.payload: payload.toMap(),
        },
      );
    } on MissingPluginException {
      throw _notEnabled();
    }
  }

  @override
  Future<String> startCustom(
      String activityType, Map<String, dynamic> data) async {
    try {
      final result = await methodChannel.invokeMethod<String>(
        NativeMethods.startCustom,
        {
          NativeMethodParams.activityType: activityType,
          NativeMethodParams.data: data,
        },
      );
      return result ?? (throw _noActivityId(NativeMethods.startCustom));
    } on MissingPluginException {
      throw _notEnabled();
    }
  }

  StateError _noActivityId(String method) => StateError(
        'Customer.io: Live Activity `$method` returned no activity id. The '
        'activity was not started, so there is nothing to update or end.',
      );

  StateError _notEnabled() => StateError(
        'Customer.io: Live Activities module is not enabled. Enable activity '
        'types in the SDK config (liveNotifications.types) before using this '
        'feature.',
      );
}
