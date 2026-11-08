import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_repository.dart';

class PlayedPuzzleStore {
  PlayedPuzzleStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  String _key(PuzzleDifficulty difficulty) =>
      'played_puzzles_${difficulty.name}';

  Future<Set<String>> ids(PuzzleDifficulty difficulty) async =>
      (await _preferences.getStringList(_key(difficulty)) ?? <String>[])
          .toSet();

  Future<void> markPlayed(PuzzleDifficulty difficulty, String id) async {
    final played = (await ids(difficulty))..add(id);
    await _preferences.setStringList(_key(difficulty), played.toList());
  }

  Future<void> reset(PuzzleDifficulty difficulty) async {
    await _preferences.remove(_key(difficulty));
  }
}
