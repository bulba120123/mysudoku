import 'dart:convert';
import 'dart:io';

const difficulties = ['easy', 'medium', 'hard', 'diabolical'];

void main(List<String> arguments) {
  if (arguments.length < 2) {
    stderr.writeln(
      '사용법: dart run tool/import_puzzles.dart <원본 폴더> <출력 폴더> [난이도별 개수]',
    );
    exitCode = 64;
    return;
  }

  final sourceDirectory = Directory(arguments[0]);
  final outputDirectory = Directory(arguments[1])..createSync(recursive: true);
  final limit = arguments.length >= 3 ? int.parse(arguments[2]) : 2000;
  final manifest = <String, Object>{
    'source': 'Sudoku Exchange Puzzle Bank',
    'repository': 'https://github.com/grantm/sudoku-exchange-puzzle-bank',
    'license': 'Public Domain',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'counts': <String, int>{},
  };

  final seen = <String>{};
  for (final difficulty in difficulties) {
    final source = File('${sourceDirectory.path}/$difficulty.txt');
    if (!source.existsSync()) {
      stderr.writeln('원본 파일이 없습니다: ${source.path}');
      exitCode = 66;
      return;
    }

    final output = File('${outputDirectory.path}/$difficulty.txt').openWrite();
    var accepted = 0;
    var rejected = 0;
    for (final line in source.readAsLinesSync()) {
      if (accepted >= limit) break;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length != 3 ||
          !RegExp(r'^[0-9a-f]{12}$').hasMatch(parts[0]) ||
          !RegExp(r'^\d{81}$').hasMatch(parts[1])) {
        rejected++;
        continue;
      }
      final puzzle = parts[1];
      if (!seen.add(puzzle)) continue;
      final board = puzzle.split('').map(int.parse).toList();
      final solutions = _solutions(board, limit: 2);
      if (solutions.length != 1) {
        rejected++;
        continue;
      }
      output.writeln(
        '${parts[0]}|${parts[2]}|$puzzle|${solutions.single.join()}',
      );
      accepted++;
    }
    output.close();
    (manifest['counts']! as Map<String, int>)[difficulty] = accepted;
    stdout.writeln('$difficulty: $accepted개 가져옴, $rejected개 제외');
  }

  File(
    '${outputDirectory.path}/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
}

List<List<int>> _solutions(List<int> puzzle, {required int limit}) {
  final board = List<int>.from(puzzle);
  final results = <List<int>>[];

  bool validGiven(int cell) {
    final number = board[cell];
    if (number == 0) return true;
    board[cell] = 0;
    final valid = !_peers(cell).any((peer) => board[peer] == number);
    board[cell] = number;
    return valid;
  }

  if (!List.generate(81, (i) => i).every(validGiven)) return results;

  void search() {
    if (results.length >= limit) return;
    var best = -1;
    Set<int>? options;
    for (var cell = 0; cell < 81; cell++) {
      if (board[cell] != 0) continue;
      final used = _peers(cell).map((peer) => board[peer]).toSet();
      final available = {
        for (var n = 1; n <= 9; n++)
          if (!used.contains(n)) n,
      };
      if (available.isEmpty) return;
      if (options == null || available.length < options.length) {
        best = cell;
        options = available;
      }
    }
    if (best == -1) {
      results.add(List<int>.from(board));
      return;
    }
    for (final number in options!) {
      board[best] = number;
      search();
      if (results.length >= limit) break;
    }
    board[best] = 0;
  }

  search();
  return results;
}

Set<int> _peers(int cell) {
  final row = cell ~/ 9;
  final column = cell % 9;
  final result = <int>{};
  for (var i = 0; i < 9; i++) {
    result.add(row * 9 + i);
    result.add(i * 9 + column);
  }
  final boxRow = row ~/ 3 * 3;
  final boxColumn = column ~/ 3 * 3;
  for (var r = boxRow; r < boxRow + 3; r++) {
    for (var c = boxColumn; c < boxColumn + 3; c++) {
      result.add(r * 9 + c);
    }
  }
  result.remove(cell);
  return result;
}
