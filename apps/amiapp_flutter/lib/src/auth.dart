import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/user.dart';
import 'utils/logs.dart';

/// Dummy authentication service as we only need login details to identify user
class AmiAppAuth extends ChangeNotifier {
  bool? _signedIn;

  bool? get signedIn => _signedIn;

  AmiAppAuth();

  // Validates current signed in state
  Future<bool> updateState() => fetchUserState().then((user) {
        _signedIn = user.isLoggedIn;
        notifyListeners();
        return _signedIn == true;
      });

  Future<void> signOut() async {
    // Sign out after short delay
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _signedIn = false;
    notifyListeners();
  }

  Future<bool> login(User user) async {
    // Sign in after short delay
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _signedIn = await saveUserState(user);
    notifyListeners();
    return _signedIn == true;
  }

  @override
  bool operator ==(Object other) =>
      other is AmiAppAuth && other._signedIn == _signedIn;

  @override
  int get hashCode => _signedIn?.hashCode ?? 0;
}

class AmiAppAuthScope extends InheritedNotifier<AmiAppAuth> {
  const AmiAppAuthScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static AmiAppAuth of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmiAppAuthScope>()!.notifier!;
}

extension AmiAppAuthExtensions on AmiAppAuth {
  Future<User?> fetchUserState() =>
      SharedPreferences.getInstance().then((prefs) {
        try {
          return User.fromPrefs(prefs);
        } catch (ex) {
          if (ex is! ArgumentError) {
            debugError("Error loading configurations from preferences: '$ex'",
                error: ex);
          }
          return null;
        }
      });

  Future<bool> saveUserState(User user) => SharedPreferences.getInstance()
      .then((prefs) => prefs.saveUserState(user));

  Future<bool> clearUserState() =>
      SharedPreferences.getInstance().then((prefs) => prefs.clearUserState());
}
