import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/game_save_store.dart';
import 'package:sudoku/data/puzzle_repository.dart';
import 'package:sudoku/game/game_history.dart';

void main() {
  test('진행 중 게임의 모든 상태를 직렬화하고 복원한다', () {
    final puzzle = SudokuPuzzle(
      id: 'test-puzzle',
      difficulty: PuzzleDifficulty.easy,
      rating: 1.2,
      puzzle: List.filled(81, '0').join(),
      solution: List.filled(81, '1').join(),
    );
    final saved = SavedGame(
      puzzle: puzzle,
      values: [1, ...List.filled(80, 0)],
      notes: [
        {2, 3},
        ...List.generate(80, (_) => <int>{}),
      ],
      eliminated: [
        {4},
        ...List.generate(80, (_) => <int>{}),
      ],
      seconds: 125,
      mistakes: 3,
      noteMode: true,
      numberFirstMode: true,
      pickedNumber: 7,
      undo: [
        GameSnapshot(
          List.filled(81, 0),
          List.generate(81, (_) => <int>{}),
          List.generate(81, (_) => <int>{}),
        ),
      ],
      redo: const [],
    );

    final restored = SavedGame.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
    );

    expect(restored.puzzle.id, 'test-puzzle');
    expect(restored.values.first, 1);
    expect(restored.notes.first, {2, 3});
    expect(restored.eliminated.first, {4});
    expect(restored.seconds, 125);
    expect(restored.mistakes, 3);
    expect(restored.noteMode, isTrue);
    expect(restored.numberFirstMode, isTrue);
    expect(restored.pickedNumber, 7);
    expect(restored.undo, hasLength(1));
  });
}
