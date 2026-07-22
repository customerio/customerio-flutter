import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

class LiveActivitiesScreen extends StatefulWidget {
  const LiveActivitiesScreen({super.key});

  @override
  State<LiveActivitiesScreen> createState() => _LiveActivitiesScreenState();
}

class _LiveActivitiesScreenState extends State<LiveActivitiesScreen> {
  String? _activityId;
  String _statusText = 'No live activity started yet';

  Future<void> _startSegments() async {
    try {
      final id = await CustomerIO.liveActivities.start(
        const LiveActivityPayload.segments(
          header: 'Order #1234',
          status: 'Preparing your order',
          substatus: 'Kitchen is working on it',
          segmentsTotal: 4,
          segmentsComplete: 1,
          trailingText: 'ETA 20 min',
        ),
      );
      setState(() {
        _activityId = id;
        _statusText = 'Started segments activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Started segments activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _startCountdown() async {
    try {
      final endTime =
          DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/
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
        _activityId = id;
        _statusText = 'Started countdown activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Started countdown activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _update() async {
    final id = _activityId;
    if (id == null) {
      context.showSnackBar('Start an activity first');
      return;
    }
    try {
      await CustomerIO.liveActivities.update(
        id,
        const LiveActivityPayload.segments(
          header: 'Order #1234',
          status: 'Out for delivery',
          substatus: 'Your courier is on the way',
          segmentsTotal: 4,
          segmentsComplete: 3,
          trailingText: 'ETA 5 min',
        ),
      );
      setState(() {
        _statusText = 'Updated activity: $id';
      });
      if (!mounted) return;
      context.showSnackBar('Updated activity');
    } catch (ex) {
      _onError(ex);
    }
  }

  Future<void> _end() async {
    final id = _activityId;
    if (id == null) {
      context.showSnackBar('Start an activity first');
      return;
    }
    try {
      await CustomerIO.liveActivities.end(id);
      setState(() {
        _statusText = 'Ended activity: $id';
        _activityId = null;
      });
      if (!mounted) return;
      context.showSnackBar('Ended activity');
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
                title: 'Start',
                description:
                    'Starts a Live Activity (iOS) / Live Notification (Android) for a built-in template.',
                child: Column(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: sizes.buttonDefault(),
                      ),
                      onPressed: _startSegments,
                      child: const Text('Start Segments'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: sizes.buttonDefault(),
                      ),
                      onPressed: _startCountdown,
                      child: const Text('Start Countdown Timer'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Update / End',
                description:
                    'Updates the running activity with a new full state, or ends it.',
                child: Column(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: sizes.buttonDefault(),
                      ),
                      onPressed: _update,
                      child: const Text('Update Activity'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: sizes.buttonDefault(),
                      ),
                      onPressed: _end,
                      child: const Text('End Activity'),
                    ),
                  ],
                ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.description,
    required this.child,
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
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
