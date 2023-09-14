import 'dart:async';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_inapp.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../auth.dart';
import '../components/container.dart';
import '../components/scroll_view.dart';
import '../customer_io.dart';
import '../data/screen.dart';
import '../random.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';
import '../utils/logs.dart';
import '../widgets/app_footer.dart';

class DashboardScreen extends StatefulWidget {
  final AmiAppAuth auth;

  const DashboardScreen({
    required this.auth,
    super.key,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _email;
  String? _buildInfo;
  late StreamSubscription inAppMessageStreamSubscription;

  @override
  void dispose() {
    /// Stop listening to streams
    inAppMessageStreamSubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    final customerIOSDK = CustomerIOSDKInstance.get();
    widget.auth
        .fetchUserState()
        .then((value) => setState(() => _email = value?.email));
    customerIOSDK
        .getBuildInfo()
        .then((value) => setState(() => _buildInfo = value));

    inAppMessageStreamSubscription =
        CustomerIO.subscribeToInAppEventListener(handleInAppEvent);
    super.initState();
  }

  void handleInAppEvent(InAppEvent event) {
    switch (event.eventType) {
      case EventType.messageShown:
        trackInAppEvent('message_shown', event.message);
        debugLog("messageShown: ${event.message}");
        break;
      case EventType.messageDismissed:
        trackInAppEvent('message_dismissed', event.message);
        debugLog("messageDismissed: ${event.message}");
        break;
      case EventType.errorWithMessage:
        trackInAppEvent('errorWithMessage', event.message);
        debugLog("errorWithMessage: ${event.message}");
        break;
      case EventType.messageActionTaken:
        trackInAppEvent('messageActionTaken', event.message, arguments: {
          'actionName': event.actionName,
          'actionValue': event.actionValue,
        });
        debugLog("messageActionTaken: ${event.message}");
        break;
    }
  }

  void trackInAppEvent(String eventName, InAppMessage message,
      {Map<String, dynamic> arguments = const {}}) {
    Map<String, dynamic> attributes = {
      'event_name': eventName,
      'message_id': message.messageId,
      'delivery_id': message.deliveryId ?? 'NULL',
    };
    attributes.addAll(arguments);

    CustomerIO.track(
      name: 'In-App Event',
      attributes: attributes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: Semantics(
              label: 'Settings',
              child: const Icon(Icons.settings),
            ),
            tooltip: 'Open SDK Configurations',
            onPressed: () {
              context.push(Screen.settings.location);
            },
          ),
        ],
      ),
      body: FullScreenScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const Spacer(),
            Center(
              child: Text(
                _email ?? '',
                semanticsLabel: 'Email ID Text',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'What would you like to test?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const _ActionList(),
            const Spacer(),
            TextFooter(text: _buildInfo ?? ''),
          ],
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList();

  final String _pushPermissionAlertTitle = 'Push Permission';

  void _sendRandomEvent(BuildContext context) {
    final randomValues = RandomValues();
    final event = randomValues.trackingEvent();
    final eventName = event.key;
    final attributes = event.value;
    if (attributes == null) {
      CustomerIO.track(name: eventName);
    } else {
      CustomerIO.track(name: eventName, attributes: attributes);
    }
    context.showSnackBar('Event sent successfully');
  }

  void _showPushPermissionStatus(BuildContext context) {
    Permission.notification.status.then((status) {
      if (status.isGranted) {
        context.showMessageDialog(_pushPermissionAlertTitle,
            'Push notifications are enabled on this device');
      } else if (status.isDenied) {
        _requestPushPermission(context);
      } else {
        _onPushPermissionPermanentlyDenied(context);
      }
    });
  }

  void _requestPushPermission(BuildContext context) {
    Permission.notification.request().then((status) {
      if (status.isGranted) {
        context.showSnackBar('Push notifications are enabled on this device');
      } else {
        _onPushPermissionPermanentlyDenied(context);
      }
    });
  }

  void _onPushPermissionPermanentlyDenied(BuildContext context) {
    context.showMessageDialog(_pushPermissionAlertTitle,
        'Push notifications are denied on this device. Please allow notification permission from settings to receive push on this device.',
        actions: [
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final authState = AmiAppAuthScope.of(context);
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;
    const actionItems = _ActionItem.values;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actionItems
            .map((item) => Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: sizes.buttonDefault(),
                    ),
                    onPressed: () {
                      switch (item) {
                        case _ActionItem.randomEvent:
                          _sendRandomEvent(context);
                          break;
                        case _ActionItem.showPushPrompt:
                          _showPushPermissionStatus(context);
                          break;
                        case _ActionItem.signOut:
                          authState.signOut();
                          break;
                        default:
                          final Screen? screen = item.targetScreen();
                          if (screen != null) {
                            context.push(screen.location);
                          }
                          break;
                      }
                    },
                    child: Text(
                      item.buildText(),
                      semanticsLabel: item.semanticsLabel(),
                    ),
                  ),
                ))
            .toList(growable: false),
      ),
    );
  }
}

/// Enum that contains actions to perform on SDK.
enum _ActionItem {
  randomEvent,
  customEvent,
  deviceAttributes,
  profileAttributes,
  showPushPrompt,
  signOut,
}

extension _ActionNames on _ActionItem {
  String buildText() {
    switch (this) {
      case _ActionItem.randomEvent:
        return 'Send Random Event';
      case _ActionItem.customEvent:
        return 'Send Custom Event';
      case _ActionItem.deviceAttributes:
        return 'Set Device Attribute';
      case _ActionItem.profileAttributes:
        return 'Set Profile Attribute';
      case _ActionItem.showPushPrompt:
        return 'Show Push Prompt';
      case _ActionItem.signOut:
        return 'Log Out';
    }
  }

  String semanticsLabel() {
    switch (this) {
      case _ActionItem.randomEvent:
        return 'Random Event Button';
      case _ActionItem.customEvent:
        return 'Custom Event Button';
      case _ActionItem.deviceAttributes:
        return 'Device Attribute Button';
      case _ActionItem.profileAttributes:
        return 'Profile Attribute Button';
      case _ActionItem.showPushPrompt:
        return 'Show Push Prompt Button';
      case _ActionItem.signOut:
        return 'Log Out Button';
    }
  }

  Screen? targetScreen() {
    switch (this) {
      case _ActionItem.randomEvent:
        return null;
      case _ActionItem.customEvent:
        return Screen.customEvents;
      case _ActionItem.deviceAttributes:
        return Screen.deviceAttributes;
      case _ActionItem.profileAttributes:
        return Screen.profileAttributes;
      case _ActionItem.showPushPrompt:
        return null;
      case _ActionItem.signOut:
        return null;
    }
  }
}
