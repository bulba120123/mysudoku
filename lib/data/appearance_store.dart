import 'package:shared_preferences/shared_preferences.dart';

class AppearanceStore {
  static const _darkModeKey = 'dark_mode';
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  Future<bool> loadDarkMode() async =>
      await _prefs.getBool(_darkModeKey) ?? false;

  Future<void> saveDarkMode(bool enabled) =>
      _prefs.setBool(_darkModeKey, enabled);
}
