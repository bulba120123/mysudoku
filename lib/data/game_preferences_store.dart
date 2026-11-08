import 'package:shared_preferences/shared_preferences.dart';

class GamePreferences {
  const GamePreferences({
    this.numberFirstMode = false,
    this.autoRemoveNotes = true,
    this.haptics = true,
    this.showTimer = true,
    this.animations = true,
  });

  final bool numberFirstMode;
  final bool autoRemoveNotes;
  final bool haptics;
  final bool showTimer;
  final bool animations;

  GamePreferences copyWith({
    bool? numberFirstMode,
    bool? autoRemoveNotes,
    bool? haptics,
    bool? showTimer,
    bool? animations,
  }) => GamePreferences(
    numberFirstMode: numberFirstMode ?? this.numberFirstMode,
    autoRemoveNotes: autoRemoveNotes ?? this.autoRemoveNotes,
    haptics: haptics ?? this.haptics,
    showTimer: showTimer ?? this.showTimer,
    animations: animations ?? this.animations,
  );
}

class GamePreferencesStore {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  Future<GamePreferences> load() async => GamePreferences(
    numberFirstMode: await _prefs.getBool('number_first_mode') ?? false,
    autoRemoveNotes: await _prefs.getBool('auto_remove_notes') ?? true,
    haptics: await _prefs.getBool('haptics') ?? true,
    showTimer: await _prefs.getBool('show_timer') ?? true,
    animations: await _prefs.getBool('animations') ?? true,
  );

  Future<void> save(GamePreferences preferences) async {
    await Future.wait([
      _prefs.setBool('number_first_mode', preferences.numberFirstMode),
      _prefs.setBool('auto_remove_notes', preferences.autoRemoveNotes),
      _prefs.setBool('haptics', preferences.haptics),
      _prefs.setBool('show_timer', preferences.showTimer),
      _prefs.setBool('animations', preferences.animations),
    ]);
  }
}
