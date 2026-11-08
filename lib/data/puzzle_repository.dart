import 'dart:math';

import 'package:flutter/services.dart';

enum PuzzleDifficulty { beginner, easy, medium, hard, expert, master }

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.id,
    required this.difficulty,
    required this.rating,
    required this.puzzle,
    required this.solution,
  });

  final String id;
  final PuzzleDifficulty difficulty;
  final double rating;
  final String puzzle;
  final String solution;
}

class PuzzleRepository {
  PuzzleRepository({AssetBundle? bundle, Random? random})
    : _bundle = bundle ?? rootBundle,
      _random = random ?? Random();

  final AssetBundle _bundle;
  final Random _random;
  final Map<PuzzleDifficulty, List<SudokuPuzzle>> _cache = {};

  Future<List<SudokuPuzzle>> load(PuzzleDifficulty difficulty) async {
    final cached = _cache[difficulty];
    if (cached != null) return cached;
    final name = difficulty.name;
    final source = await _bundle.loadString('assets/puzzles/$name.txt');
    final puzzles = source
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final fields = line.trim().split('|');
          if (fields.length != 4 ||
              fields[2].length != 81 ||
              fields[3].length != 81) {
            throw const FormatException('잘못된 스도쿠 문제 데이터입니다.');
          }
          return SudokuPuzzle(
            id: fields[0],
            difficulty: difficulty,
            rating: double.parse(fields[1]),
            puzzle: fields[2],
            solution: fields[3],
          );
        })
        .toList(growable: false);
    if (puzzles.isEmpty) throw StateError('$name 문제가 없습니다.');
    _cache[difficulty] = puzzles;
    return puzzles;
  }

  Future<SudokuPuzzle> randomPuzzle(PuzzleDifficulty difficulty) async {
    final puzzles = await load(difficulty);
    return puzzles[_random.nextInt(puzzles.length)];
  }

  Future<SudokuPuzzle?> randomUnplayed(
    PuzzleDifficulty difficulty,
    Set<String> playedIds,
  ) async {
    final puzzles = await load(difficulty);
    final available = puzzles
        .where((puzzle) => !playedIds.contains(puzzle.id))
        .toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }
}
