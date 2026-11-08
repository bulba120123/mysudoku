import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/puzzle_repository.dart';
import 'package:sudoku/game/sudoku_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('전문가와 마스터 문제에서 힌트가 정답 후보를 제거하지 않는다', () async {
    final repository = PuzzleRepository();
    final puzzles = <SudokuPuzzle>[
      ...(await repository.load(PuzzleDifficulty.expert)).take(10),
      ...(await repository.load(PuzzleDifficulty.master)).take(10),
    ];
    var advancedHints = 0;
    final techniques = <String>{};

    for (final puzzle in puzzles) {
      final board = puzzle.puzzle.split('').map(int.parse).toList();
      final solution = puzzle.solution.split('').map(int.parse).toList();
      final eliminated = List.generate(81, (_) => <int>{});
      for (var step = 0; step < 500 && board.contains(0); step++) {
        final hint = SudokuLogic.find(board, eliminated: eliminated);
        if (hint == null) break;
        techniques.add(hint.technique);
        if (!hint.technique.contains('Single') &&
            !hint.technique.contains('Locked') &&
            !hint.technique.contains('Naked Pair') &&
            !hint.technique.contains('X-Wing')) {
          advancedHints++;
        }
        if (hint.cell != null) {
          expect(
            hint.number,
            solution[hint.cell!],
            reason: '${puzzle.id}: ${hint.technique}이 잘못된 숫자를 확정했습니다.',
          );
          board[hint.cell!] = hint.number!;
          eliminated[hint.cell!].clear();
        } else {
          var changed = false;
          for (final removal in hint.removals.entries) {
            for (final number in removal.value) {
              expect(
                number,
                isNot(solution[removal.key]),
                reason: '${puzzle.id}: ${hint.technique}이 정답 후보를 제거했습니다.',
              );
              changed = eliminated[removal.key].add(number) || changed;
            }
          }
          expect(changed, isTrue, reason: '같은 후보 제거 힌트가 반복되었습니다.');
        }
      }
    }

    expect(advancedHints, greaterThan(0));
    expect(techniques.length, greaterThanOrEqualTo(5));
  });
}
