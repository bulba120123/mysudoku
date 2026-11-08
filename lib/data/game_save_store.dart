import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_history.dart';
import 'puzzle_repository.dart';

class SavedGame {
  const SavedGame({
    required this.puzzle,
    required this.values,
    required this.notes,
    required this.eliminated,
    required this.seconds,
    required this.mistakes,
    required this.noteMode,
    required this.numberFirstMode,
    required this.pickedNumber,
    required this.undo,
    required this.redo,
  });

  final SudokuPuzzle puzzle;
  final List<int> values;
  final List<Set<int>> notes;
  final List<Set<int>> eliminated;
  final int seconds;
  final int mistakes;
  final bool noteMode;
  final bool numberFirstMode;
  final int? pickedNumber;
  final List<GameSnapshot> undo;
  final List<GameSnapshot> redo;

  Map<String, Object?> toJson() => {
    'version': 1,
    'puzzle': {
      'id': puzzle.id,
      'difficulty': puzzle.difficulty.name,
      'rating': puzzle.rating,
      'puzzle': puzzle.puzzle,
      'solution': puzzle.solution,
    },
    'values': values,
    'notes': notes.map((note) => note.toList()).toList(),
    'eliminated': eliminated.map((values) => values.toList()).toList(),
    'seconds': seconds,
    'mistakes': mistakes,
    'noteMode': noteMode,
    'numberFirstMode': numberFirstMode,
    'pickedNumber': pickedNumber,
    'undo': _recent(undo).map(_snapshotToJson).toList(),
    'redo': _recent(redo).map(_snapshotToJson).toList(),
  };

  factory SavedGame.fromJson(Map<String, dynamic> json) {
    final puzzleJson = json['puzzle']! as Map<String, dynamic>;
    final difficulty = PuzzleDifficulty.values.byName(
      puzzleJson['difficulty']! as String,
    );
    return SavedGame(
      puzzle: SudokuPuzzle(
        id: puzzleJson['id']! as String,
        difficulty: difficulty,
        rating: (puzzleJson['rating']! as num).toDouble(),
        puzzle: puzzleJson['puzzle']! as String,
        solution: puzzleJson['solution']! as String,
      ),
      values: (json['values']! as List)
          .cast<num>()
          .map((n) => n.toInt())
          .toList(),
      notes: (json['notes']! as List)
          .map(
            (note) => (note as List).cast<num>().map((n) => n.toInt()).toSet(),
          )
          .toList(),
      eliminated:
          ((json['eliminated'] as List?) ?? List.generate(81, (_) => <int>[]))
              .map(
                (values) =>
                    (values as List).cast<num>().map((n) => n.toInt()).toSet(),
              )
              .toList(),
      seconds: (json['seconds']! as num).toInt(),
      mistakes: (json['mistakes']! as num).toInt(),
      noteMode: json['noteMode']! as bool,
      numberFirstMode: json['numberFirstMode'] as bool? ?? false,
      pickedNumber: (json['pickedNumber'] as num?)?.toInt(),
      undo: (json['undo']! as List)
          .map((item) => _snapshotFromJson(item as Map<String, dynamic>))
          .toList(),
      redo: (json['redo']! as List)
          .map((item) => _snapshotFromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

Map<String, Object?> _snapshotToJson(GameSnapshot snapshot) => {
  'values': snapshot.values,
  'notes': snapshot.notes.map((note) => note.toList()).toList(),
  'eliminated': snapshot.eliminated.map((values) => values.toList()).toList(),
};

Iterable<GameSnapshot> _recent(List<GameSnapshot> snapshots) =>
    snapshots.length <= 100
    ? snapshots
    : snapshots.skip(snapshots.length - 100);

GameSnapshot _snapshotFromJson(Map<String, dynamic> json) => GameSnapshot(
  (json['values']! as List).cast<num>().map((n) => n.toInt()).toList(),
  (json['notes']! as List)
      .map((note) => (note as List).cast<num>().map((n) => n.toInt()).toSet())
      .toList(),
  ((json['eliminated'] as List?) ?? List.generate(81, (_) => <int>[]))
      .map(
        (values) => (values as List).cast<num>().map((n) => n.toInt()).toSet(),
      )
      .toList(),
);

class GameSaveStore {
  static const _key = 'active_game_v1';
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  Future<SavedGame?> load() async {
    final encoded = await _prefs.getString(_key);
    if (encoded == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(SavedGame game) async {
    await _prefs.setString(_key, jsonEncode(game.toJson()));
  }

  Future<void> clear() => _prefs.remove(_key);
}
