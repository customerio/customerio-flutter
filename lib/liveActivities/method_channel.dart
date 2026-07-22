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
      return result ?? '';
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
  Future<void> end(String activityId) async {
    try {
      await methodChannel.invokeMethod<void>(
        NativeMethods.end,
        {NativeMethodParams.activityId: activityId},
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
      return result ?? '';
    } on MissingPluginException {
      throw _notEnabled();
    }
  }

  @override
  Future<bool> handleDeepLinkOpen(String url) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        NativeMethods.handleDeepLinkOpen,
        {NativeMethodParams.url: url},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  StateError _notEnabled() => StateError(
        'Customer.io: Live Activities module is not enabled. Enable live '
        'activity templates in the SDK config (liveActivities) before using '
        'this feature.',
      );
}
