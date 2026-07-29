import 'dart:developer';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_widgets.dart';
import 'package:customer_io/messaging_in_app.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';

/// Demonstrates the three native Visual Notification Inbox UI components exposed
/// via PlatformView:
///   1. NotificationInboxOverlay (drop-in bell + slide-out panel)
///   2. NotificationInboxBell    (bell only; host opens its own UI)
///   3. NotificationInboxView    (the Jist-rendered message list)
///
/// Message actions are handled by the global InboxEventListener (bridged
/// separately); these widgets only render UI and surface widget-level callbacks.
class InboxUiScreen extends StatefulWidget {
  const InboxUiScreen({super.key});

  @override
  State<InboxUiScreen> createState() => _InboxUiScreenState();
}

class _InboxUiScreenState extends State<InboxUiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Last inbox event surfaced by the global [InboxEventListener], shown on-screen.
  String _lastInboxEvent = 'No inbox events yet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Register a global inbox event listener. While registered, the Flutter host
    // owns inbox action navigation (the SDK suppresses its default handling).
    CustomerIO.inAppMessaging.setInboxEventListener(
      _DemoInboxEventListener(
        onEvent: (summary) {
          log('[InboxEventListener] $summary');
          if (mounted) {
            setState(() => _lastInboxEvent = summary);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    // Clear the listener so the SDK restores its default action handling.
    CustomerIO.inAppMessaging.setInboxEventListener(null);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      appBar: AppBar(
        title: const Text('Inbox UI Components'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overlay'),
            Tab(text: 'Bell'),
            Tab(text: 'List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverlayTab(),
          _buildBellTab(),
          _buildListTab(),
        ],
      ),
    );
  }

  // 1. Drop-in overlay (bell + slide-out panel). The overlay paints itself over
  // the whole area, so we let it fill a Stack on top of placeholder content.
  Widget _buildOverlayTab() {
    return Stack(
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'NotificationInboxOverlay renders a floating bell and a slide-out '
              'panel on top of your content. Tap the bell to open the panel.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // The overlay manages its own layout; give it the full area.
        const Positioned.fill(
          child: NotificationInboxOverlay(),
        ),
        // Readout LAST, so it paints above the overlay. Native platform views draw over earlier
        // Flutter siblings in a Stack (notably on Android), so ordering this before the overlay hid
        // the very callbacks this screen exists to show.
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'last inbox event: $_lastInboxEvent',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Bell only — host opens its own UI on tap (here we push the list screen).
  Widget _buildBellTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'NotificationInboxBell renders only the bell. On tap, the host '
              'decides what to show.',
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: NotificationInboxBell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _InboxListPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3. The Jist-rendered message list, embedded directly.
  Widget _buildListTab() {
    return const NotificationInboxView();
  }
}

/// Demo [InboxEventListener] that reports each callback as a short summary
/// string. All callbacks are observational; because a listener is registered,
/// the host owns inbox action navigation (the SDK does not open urls itself).
class _DemoInboxEventListener implements InboxEventListener {
  _DemoInboxEventListener({required this.onEvent});

  final void Function(String summary) onEvent;

  @override
  void messageActionTaken(
      InboxMessage message, String actionName, String actionValue) {
    onEvent(
        'actionTaken queueId=${message.queueId} action=$actionName value=$actionValue');
  }

  @override
  void messageShown(InboxMessage message) {
    onEvent('shown queueId=${message.queueId}');
  }

  @override
  void messageOpened(InboxMessage message) {
    onEvent('opened queueId=${message.queueId}');
  }

  @override
  void messageDismissed(InboxMessage message) {
    onEvent('dismissed queueId=${message.queueId}');
  }
}

/// A simple screen hosting just the [NotificationInboxView], used to demonstrate
/// the host-opens-its-own-UI flow from [NotificationInboxBell].
class _InboxListPage extends StatelessWidget {
  const _InboxListPage();

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      appBar: AppBar(
        title: const Text('Notification Inbox'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const NotificationInboxView(),
    );
  }
}
