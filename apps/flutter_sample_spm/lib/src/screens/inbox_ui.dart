import 'dart:developer';

import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';

/// Demonstrates the two native Visual Notification Inbox UI components exposed via
/// PlatformView:
///   1. NotificationInboxBell — the branded bell; tapping it opens the SDK's own panel
///   2. NotificationInboxView — the Jist-rendered message list
///
/// This screen deliberately does NOT register an `InboxEventListener`. Doing so transfers inbox
/// action navigation to the host: the MethodChannel is async, so the native bridge cannot round-trip
/// a bool back to the SDK's calling thread and instead reports every action as host-handled, which
/// suppresses the SDK's own url and deeplink handling. Left unregistered, tapping a message action
/// exercises the SDK's built-in navigation — which is what most integrators want and what this
/// screen is here to show.
///
/// Apps that do want to own navigation should register a listener and act on `actionValue` in
/// `messageActionTaken`; see the docs on `InboxEventListener`. The bridge itself is covered by
/// `test/messaging_in_app/inbox_event_listener_test.dart`.
class InboxUiScreen extends StatefulWidget {
  const InboxUiScreen({super.key});

  @override
  State<InboxUiScreen> createState() => _InboxUiScreenState();
}

class _InboxUiScreenState extends State<InboxUiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Last observational bell tap, shown on-screen.
  String _lastBellTap = 'No bell taps yet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
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
            Tab(text: 'Bell'),
            Tab(text: 'List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBellTab(),
          _buildListTab(),
        ],
      ),
    );
  }

  // 1. The branded bell. Tapping it opens the SDK's own panel — the host presents
  // nothing. `onTap` is observational only.
  Widget _buildBellTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tapping the bell opens the inbox panel the SDK owns. Remote branding '
              'styles the bell; this screen decides where it sits. Message actions are '
              'navigated by the SDK, because no InboxEventListener is registered here.',
              textAlign: TextAlign.center,
            ),
          ),
          // 88 not 64: the native composition insets its 56 bell by 16 per side, so a
          // smaller box squeezes the circle onto the glyph.
          SizedBox(
            width: 88,
            height: 88,
            child: NotificationInboxBell(
              onTap: () {
                log('[NotificationInboxBell] onTap (observational)');
                if (mounted) {
                  setState(() => _lastBellTap = 'bell tapped');
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'last bell tap: $_lastBellTap',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 2. The Jist-rendered message list, embedded directly.
  Widget _buildListTab() {
    return const NotificationInboxView();
  }
}
