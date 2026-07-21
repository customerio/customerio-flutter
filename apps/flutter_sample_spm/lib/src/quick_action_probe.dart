import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Exercises Flutter plugins that register an iOS application delegate.
class QuickActionProbe extends ChangeNotifier {
  static const shortcutType = 'lifecycle_probe';

  final QuickActions _quickActions;

  QuickActionProbe({QuickActions quickActions = const QuickActions()})
      : _quickActions = quickActions;

  String? _lastAction;
  int _callbackCount = 0;

  String? get lastAction => _lastAction;
  int get callbackCount => _callbackCount;

  Future<void> initialize() async {
    await _quickActions.initialize(_handleAction);
    await _quickActions.setShortcutItems(const [
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
