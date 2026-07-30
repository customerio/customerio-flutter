import 'dart:developer';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_widgets.dart';
import 'package:customer_io/messaging_in_app.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/container.dart';

/// Demonstrates the two native Visual Notification Inbox UI components exposed via
/// PlatformView:
///   1. NotificationInboxBell — the branded bell; tapping it opens the SDK's own panel
///   2. NotificationInboxView — the Jist-rendered message list
///
/// Message actions are handled by the global InboxEventListener (bridged
/// separately); these widgets only render UI.
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

  /// Last observational bell tap. Kept separate from [_lastInboxEvent]: the listener's
  /// `shown` events fire as soon as the panel renders and would otherwise overwrite it.
  String _lastBellTap = 'No bell taps yet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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
        onAction: _openInboxAction,
      ),
    );
  }

  /// Navigates for a tapped inbox action.
  ///
  /// Registering a listener makes this app the owner of inbox action navigation — the native
  /// forwarder reports every action as host-handled, so the SDK opens nothing and a listener that
  /// only logs would make inbox taps look broken. Hand the value to the OS the way the SDK would:
  /// this app's own `flutter-spm` scheme round-trips back through its deep-link handling, anything
  /// else opens externally.
  Future<void> _openInboxAction(String actionValue) async {
    if (actionValue.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(actionValue);
    if (uri == null) {
      log('[InboxEventListener] unparseable action value: $actionValue');
      if (mounted) {
        setState(() => _lastInboxEvent = 'could not parse $actionValue');
      }
      return;
    }

    // Deliberately no `canLaunchUrl` precheck: on iOS it reports false for any scheme missing from
    // LSApplicationQueriesSchemes even when launching would succeed, so it would refuse valid links.
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _lastInboxEvent = 'could not open $actionValue');
      }
    } catch (error) {
      log('[InboxEventListener] failed to open $actionValue: $error');
      if (mounted) {
        setState(() => _lastInboxEvent = 'could not open $actionValue');
      }
    }
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
              'styles the bell; this screen decides where it sits.',
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
            child: Column(
              children: [
                Text(
                  'last bell tap: $_lastBellTap',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'last inbox event: $_lastInboxEvent',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
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

/// Demo [InboxEventListener] that reports each callback as a short summary
/// string. Because a listener is registered, the host owns inbox action navigation — the SDK does
/// not open urls itself — so [onAction] carries the tapped action's value out to be navigated.
class _DemoInboxEventListener implements InboxEventListener {
  _DemoInboxEventListener({required this.onEvent, required this.onAction});

  final void Function(String summary) onEvent;

  /// Called with the action's resolved value (typically its url) so the host can navigate.
  final void Function(String actionValue) onAction;

  @override
  void messageActionTaken(
      InboxMessage message, String actionName, String actionValue) {
    onEvent(
        'actionTaken queueId=${message.queueId} action=$actionName value=$actionValue');
    onAction(actionValue);
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
