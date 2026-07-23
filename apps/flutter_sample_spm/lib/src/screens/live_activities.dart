import 'dart:io' show Platform;

import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

/// Identifier of the custom (app-defined) live activity type demonstrated here.
/// Matches the type registered in the SDK config (`customTypes`), the Android
/// sample's `createLiveNotification` callback, and the iOS sample's native
/// widget/handler.
const String _rideshareType = 'io.customer.livenotifications.custom.rideshare';

/// Channel to the iOS sample's app-owned custom Live Activity handler
/// (see `Runner/SampleCustomLiveActivity.swift`). Custom types on iOS require a
/// native Widget Extension and are owned by the app, not the wrapper SDK.
const MethodChannel _customIosChannel =
    MethodChannel('sample_custom_live_activity');

class LiveActivitiesScreen extends StatefulWidget {
  const LiveActivitiesScreen({super.key});

  @override
  State<LiveActivitiesScreen> createState() => _LiveActivitiesScreenState();
}

class _LiveActivitiesScreenState extends State<LiveActivitiesScreen> {
  String? _segmentsId;
  int _segmentsComplete = 1;
  String? _countdownId;
  String? _customId;
  String _statusText = 'No live activity started yet';

  // MARK: - Segments

  Future<void> _startSegments() async {
    try {
      final id = await CustomerIO.liveActivities.start(
        LiveActivityPayload.segments(
          header: 'Order #1234',
          status: 'Preparing your order',
          substatus: 'Kitchen is working on it',
          segmentsTotal: 4,
          segmentsComplete: _segmentsComplete,
          trailingText: 'ETA 20 min',
        ),
      );
      setState(() {
        _segmentsId = id;
        _statusText = 'Started segments activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Started segments activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _advanceSegments() async {
    final id = _segmentsId;
    if (id == null) {
      context.showSnackBar('Start the segments activity first');
      return;
    }
    final complete = (_segmentsComplete + 1).clamp(0, 4);
    try {
      await CustomerIO.liveActivities.update(
        id,
        LiveActivityPayload.segments(
          header: 'Order #1234',
          status: complete >= 4 ? 'Delivered' : 'Out for delivery',
          substatus: complete >= 4
              ? 'Enjoy your order'
              : 'Your courier is on the way',
          segmentsTotal: 4,
          segmentsComplete: complete,
          trailingText: complete >= 4 ? 'Done' : 'ETA 5 min',
        ),
      );
      setState(() {
        _segmentsComplete = complete;
        _statusText = 'Advanced segments activity ($complete/4): $id';
      });
      if (!mounted) return;
      context.showSnackBar('Advanced segments activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _endSegments() async {
    final id = _segmentsId;
    if (id == null) {
      context.showSnackBar('Start the segments activity first');
      return;
    }
    try {
      await CustomerIO.liveActivities.end(id);
      setState(() {
        _statusText = 'Ended segments activity: $id';
        _segmentsId = null;
        _segmentsComplete = 1;
      });
      if (!mounted) return;
      context.showSnackBar('Ended segments activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  // MARK: - Countdown Timer

  Future<void> _startCountdown() async {
    try {
      final endTime =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      final id = await CustomerIO.liveActivities.start(
        LiveActivityPayload.countdownTimer(
          header: 'Flash Sale',
          title: 'Ends soon!',
          statusMessage: 'Hurry before it is gone',
          endTime: endTime,
        ),
      );
      setState(() {
        _countdownId = id;
        _statusText = 'Started countdown activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Started countdown activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _endCountdown() async {
    final id = _countdownId;
    if (id == null) {
      context.showSnackBar('Start the countdown activity first');
      return;
    }
    try {
      await CustomerIO.liveActivities.end(id);
      setState(() {
        _statusText = 'Ended countdown activity: $id';
        _countdownId = null;
      });
      if (!mounted) return;
      context.showSnackBar('Ended countdown activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  // MARK: - Custom (Rideshare)

  Future<void> _startCustom() async {
    try {
      final String id;
      if (Platform.isIOS) {
        // Custom types on iOS are owned by the app's native Widget Extension.
        id = await _customIosChannel.invokeMethod<String>('startRideshare', {
              'driverName': 'Alex',
              'status': 'On the way',
              'etaMinutes': 5,
            }) ??
            '';
      } else {
        // Android renders custom live notifications via the app's
        // createLiveNotification callback (registered before SDK init).
        id = await CustomerIO.liveActivities.startCustom(_rideshareType, {
          'driverName': 'Alex',
          'status': 'On the way',
          'etaMinutes': 5,
        });
      }
      setState(() {
        _customId = id;
        _statusText = 'Started custom rideshare activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Started custom rideshare activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _updateCustom() async {
    final id = _customId;
    if (id == null) {
      context.showSnackBar('Start the custom activity first');
      return;
    }
    try {
      String currentId = id;
      if (Platform.isIOS) {
        await _customIosChannel.invokeMethod<void>('updateRideshare', {
          'activityId': id,
          'status': 'Arriving now',
          'etaMinutes': 1,
        });
      } else {
        // The wrapper exposes startCustom (which mints a fresh activity id) but
        // no stable-id custom update. End the current notification first, then
        // re-issue startCustom and track the new id, so we replace it in place
        // instead of stacking a second notification and orphaning the previous one.
        await CustomerIO.liveActivities.end(id);
        currentId = await CustomerIO.liveActivities.startCustom(_rideshareType, {
          'driverName': 'Alex',
          'status': 'Arriving now',
          'etaMinutes': 1,
        });
      }
      setState(() {
        _customId = currentId;
        _statusText = 'Updated custom rideshare activity: $currentId';
      });
      if (!mounted) return;
      context.showSnackBar('Updated custom rideshare activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _endCustom() async {
    final id = _customId;
    if (id == null) {
      context.showSnackBar('Start the custom activity first');
      return;
    }
    try {
      if (Platform.isIOS) {
        await _customIosChannel.invokeMethod<void>('endRideshare', {
          'activityId': id,
        });
      } else {
        await CustomerIO.liveActivities.end(id);
      }
      setState(() {
        _statusText = 'Ended custom rideshare activity: $id';
        _customId = null;
      });
      if (!mounted) return;
      context.showSnackBar('Ended custom rideshare activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  void _onError(Object ex) {
    setState(() {
      _statusText = 'Error: $ex';
    });
    if (!mounted) return;
    context.showSnackBar('Error: $ex');
  }

  @override
  Widget build(BuildContext context) {
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;
    final theme = Theme.of(context);

    return AppContainer(
      appBar: AppBar(
        backgroundColor: null,
      ),
      body: FullScreenScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Activities Testing',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Segments',
                description:
                    'Built-in segmented progress template. Advance increments the '
                    'completed segments; End dismisses it.',
                children: [
                  _SectionButton(
                    label: 'Start',
                    sizes: sizes,
                    onPressed: _startSegments,
                  ),
                  _SectionButton(
                    label: 'Advance',
                    sizes: sizes,
                    onPressed: _advanceSegments,
                  ),
                  _SectionButton(
                    label: 'End',
                    sizes: sizes,
                    onPressed: _endSegments,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Countdown Timer',
                description:
                    'Built-in countdown template counting down to one hour from '
                    'now.',
                children: [
                  _SectionButton(
                    label: 'Start',
                    sizes: sizes,
                    onPressed: _startCountdown,
                  ),
                  _SectionButton(
                    label: 'End',
                    sizes: sizes,
                    onPressed: _endCountdown,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Custom (Rideshare)',
                description:
                    'App-defined type rendered by the app: a NotificationCompat '
                    'callback on Android, a native Widget Extension on iOS.',
                children: [
                  _SectionButton(
                    label: 'Start',
                    sizes: sizes,
                    onPressed: _startCustom,
                  ),
                  _SectionButton(
                    label: 'Update',
                    sizes: sizes,
                    onPressed: _updateCustom,
                  ),
                  _SectionButton(
                    label: 'End',
                    sizes: sizes,
                    onPressed: _endCustom,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  final String label;
  final Sizes sizes;
  final VoidCallback onPressed;

  const _SectionButton({
    required this.label,
    required this.sizes,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: sizes.buttonDefault(),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
