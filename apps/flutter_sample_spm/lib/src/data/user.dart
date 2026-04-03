import 'package:shared_preferences/shared_preferences.dart';

class User {
  String displayName;
  String email;
  bool isGuest;

  User({
    required this.displayName,
    required this.email,
    required this.isGuest,
  });

  factory User.fromPrefs(SharedPreferences prefs) {
    final email = prefs.getString(_PreferencesKey.email);

    if (email == null) {
      throw ArgumentError('email cannot be null');
    }

    return User(
      displayName: prefs.getString(_PreferencesKey.displayName) ?? '',
      email: email,
      isGuest: prefs.getBool(_PreferencesKey.isGuest) != true,
    );
  }
}

extension UserExtensions on User? {
  bool get isLoggedIn => this?.email.isNotEmpty == true;
}

extension UserPreferencesExtensions on SharedPreferences {
  Future<bool> saveUserState(User user) async {
    bool result = true;
    result = result &&
        await setString(_PreferencesKey.displayName, user.displayName);
    result = result && await setString(_PreferencesKey.email, user.email);
    result = result && await setBool(_PreferencesKey.isGuest, user.isGuest);
    return result;
  }

  Future<bool> clearUserState() async {
    bool result = true;
    result = result && await remove(_PreferencesKey.displayName);
    result = result && await remove(_PreferencesKey.email);
    result = result && await remove(_PreferencesKey.isGuest);
    return result;
  }
}

class _PreferencesKey {
  static const displayName = 'DISPLAY_NAME';
  static const email = 'EMAIL';
  static const isGuest = 'IS_GUEST';
}
