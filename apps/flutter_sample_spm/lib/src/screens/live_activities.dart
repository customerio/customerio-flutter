import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

/// Content-state for the custom "rideshare" activity demonstrated here.
///
/// One code path on both platforms. The SDK owns the attributes type, so the payload is
/// just a map of strings: iOS renders it from `CIOCustomAttributes` in the Widget
/// Extension, Android from the app's `createLiveNotification` callback (registered in
/// MainActivity). The activity is named by `customType` in the SDK config, not here.
LiveActivityPayload _rideshare(String status, int etaMinutes) =>
    LiveActivityPayload.custom(
      // Values are strings — a bridge payload carries no schema, so the renderer parses
      // whatever it needs.
      data: {
        'driverName': 'Alex',
        'status': status,
        'etaMinutes': '$etaMinutes',
      },
    );

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
      if (!mounted) return;
      setState(() {
        _segmentsId = id;
        _statusText = 'Started segments activity: $id';
      });
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
      if (!mounted) return;
      setState(() {
        _segmentsComplete = complete;
        _statusText = 'Advanced segments activity ($complete/4): $id';
      });
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
      // Pass a final content-state so iOS renders a terminal card instead of freezing on the last
      // progress value. Android ignores it and renders its own terminal state.
      await CustomerIO.liveActivities.end(
        id,
        payload: const LiveActivityPayload.segments(
          header: 'Order #1234',
          status: 'Delivered',
          substatus: 'Enjoy your order',
          segmentsTotal: 4,
          segmentsComplete: 4,
        ),
      );
      if (!mounted) return;
      setState(() {
        _statusText = 'Ended segments activity: $id';
        _segmentsId = null;
        _segmentsComplete = 1;
      });
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
      if (!mounted) return;
      setState(() {
        _countdownId = id;
        _statusText = 'Started countdown activity: $id';
      });
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
      // Terminal state: drop the endTime so the card reads as finished rather than counting down.
      await CustomerIO.liveActivities.end(
        id,
        payload: const LiveActivityPayload.countdownTimer(
          header: 'Flash Sale',
          title: 'Sale ended',
          statusMessage: 'Thanks for shopping',
        ),
      );
      if (!mounted) return;
      setState(() {
        _statusText = 'Ended countdown activity: $id';
        _countdownId = null;
      });
      context.showSnackBar('Ended countdown activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  // MARK: - Custom (Rideshare)

  Future<void> _startCustom() async {
    try {
      final id = await CustomerIO.liveActivities.start(
        _rideshare('On the way', 5),
      );
      if (!mounted) return;
      setState(() {
        _customId = id;
        _statusText = 'Started custom rideshare activity: $id';
      });
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
      await CustomerIO.liveActivities.update(id, _rideshare('Arriving now', 1));
      if (!mounted) return;
      setState(() {
        _statusText = 'Updated custom rideshare activity: $id';
      });
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
      // A final content-state so the card reads as finished rather than freezing mid-trip.
      await CustomerIO.liveActivities.end(
        id,
        payload: _rideshare('Arrived', 0),
      );
      if (!mounted) return;
      setState(() {
        _statusText = 'Ended custom rideshare activity: $id';
        _customId = null;
      });
      context.showSnackBar('Ended custom rideshare activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  void _onError(Object ex) {
    if (!mounted) return;
    setState(() {
      _statusText = 'Error: $ex';
    });
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
                    'Your own type, started the same way on both platforms. The SDK '
                    'owns the attributes type; the app supplies the view — a '
                    'NotificationCompat callback on Android, a Widget Extension on iOS.',
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
