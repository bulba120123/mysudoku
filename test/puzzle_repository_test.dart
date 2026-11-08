import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/puzzle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('난이도별 퍼즐 에셋을 읽고 정답을 제공한다', () async {
    final repository = PuzzleRepository();
    const expectedCounts = {
      PuzzleDifficulty.beginner: 2000,
      PuzzleDifficulty.easy: 2000,
      PuzzleDifficulty.medium: 2000,
      PuzzleDifficulty.hard: 2000,
      PuzzleDifficulty.expert: 1530,
      PuzzleDifficulty.master: 470,
    };

    for (final difficulty in PuzzleDifficulty.values) {
      final puzzles = await repository.load(difficulty);
      expect(puzzles, hasLength(expectedCounts[difficulty]));
      expect(puzzles.first.puzzle, hasLength(81));
      expect(puzzles.first.solution, hasLength(81));
      expect(puzzles.first.difficulty, difficulty);
    }
  });

  test('이미 출제된 문제를 제외하고 새 문제를 고른다', () async {
    final repository = PuzzleRepository();
    final puzzles = await repository.load(PuzzleDifficulty.easy);
    final remaining = puzzles.last;
    final playedIds = puzzles
        .take(puzzles.length - 1)
        .map((puzzle) => puzzle.id)
        .toSet();

    final selected = await repository.randomUnplayed(
      PuzzleDifficulty.easy,
      playedIds,
    );

    expect(selected?.id, remaining.id);
  });

  test('새 난이도 단계의 단서 수와 점수 경계를 지킨다', () async {
    final repository = PuzzleRepository();
    final beginner = await repository.load(PuzzleDifficulty.beginner);
    final easy = await repository.load(PuzzleDifficulty.easy);
    final expert = await repository.load(PuzzleDifficulty.expert);
    final master = await repository.load(PuzzleDifficulty.master);

    expect(
      beginner.every(
        (puzzle) => puzzle.puzzle.replaceAll('0', '').length >= 45,
      ),
      isTrue,
    );
    expect(
      easy.every((puzzle) => puzzle.puzzle.replaceAll('0', '').length >= 36),
      isTrue,
    );
    expect(expert.every((puzzle) => puzzle.rating <= 7.4), isTrue);
    expect(master.every((puzzle) => puzzle.rating > 7.4), isTrue);
  });
}
