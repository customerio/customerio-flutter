import 'package:flutter/foundation.dart';
import 'package:quick_actions_ios/quick_actions_ios.dart';

/// Exercises Flutter plugins that register an iOS application delegate.
class QuickActionProbe extends ChangeNotifier {
  static const shortcutType = 'lifecycle_probe';

  String? _lastAction;
  int _callbackCount = 0;

  String? get lastAction => _lastAction;
  int get callbackCount => _callbackCount;

  Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final quickActions = QuickActionsIos();
    await quickActions.initialize(_handleAction);
    await quickActions.setShortcutItems(const [
      ShortcutItem(
        type: shortcutType,
        localizedTitle: 'Test Flutter lifecycle',
        localizedSubtitle: 'Verify the app delegate callback',
      ),
    ]);
  }

  void _handleAction(String shortcutType) {
    _lastAction = shortcutType;
    _callbackCount++;
    notifyListeners();
  }
}
