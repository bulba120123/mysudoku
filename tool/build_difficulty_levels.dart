import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final directory = Directory(
    arguments.isEmpty ? 'assets/puzzles' : arguments.first,
  );
  final easySource = _read(File('${directory.path}/easy.txt'));
  final expertSource = _read(File('${directory.path}/diabolical.txt'));

  final beginner = <PuzzleLine>[];
  final easy = <PuzzleLine>[];
  for (final source in easySource) {
    beginner.add(
      _derive(source, targetClues: 45, hiddenSingles: false, prefix: 'b'),
    );
    easy.add(
      _derive(source, targetClues: 36, hiddenSingles: true, prefix: 'e'),
    );
  }

  final expert = expertSource.where((puzzle) => puzzle.rating <= 7.4).toList();
  final master = expertSource.where((puzzle) => puzzle.rating > 7.4).toList();
  if (expert.isEmpty || master.isEmpty) {
    throw StateError('전문가/마스터 데이터 분리에 실패했습니다.');
  }

  _write(File('${directory.path}/beginner.txt'), beginner);
  _write(File('${directory.path}/easy.txt'), easy);
  _write(File('${directory.path}/expert.txt'), expert);
  _write(File('${directory.path}/master.txt'), master);
  File('${directory.path}/diabolical.txt').deleteSync();

  final manifestFile = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  manifest['generatedAt'] = DateTime.now().toUtc().toIso8601String();
  manifest['counts'] = {
    'beginner': beginner.length,
    'easy': easy.length,
    'medium': _lineCount(File('${directory.path}/medium.txt')),
    'hard': _lineCount(File('${directory.path}/hard.txt')),
    'expert': expert.length,
    'master': master.length,
  };
  manifest['derivedLevels'] = {
    'beginner':
        'Original easy puzzles with added clues; solvable by naked singles.',
    'easy':
        'Original easy puzzles with added clues; solvable by naked and hidden singles.',
    'expert': 'Original diabolical puzzles rated 5.0 through 7.4.',
    'master': 'Original diabolical puzzles rated above 7.4.',
  };
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );

  stdout.writeln('beginner: ${beginner.length}');
  stdout.writeln('easy: ${easy.length}');
  stdout.writeln('expert: ${expert.length}');
  stdout.writeln('master: ${master.length}');
}

PuzzleLine _derive(
  PuzzleLine source, {
  required int targetClues,
  required bool hiddenSingles,
  required String prefix,
}) {
  final board = source.puzzle.split('').map(int.parse).toList();
  final solution = source.solution.split('').map(int.parse).toList();
  final blanks = [
    for (var i = 0; i < 81; i++)
      if (board[i] == 0) i,
  ];
  _shuffle(
    blanks,
    source.id.codeUnits.fold(0, (value, item) => value * 31 + item),
  );
  var cursor = 0;
  while (board.where((value) => value != 0).length < targetClues &&
      cursor < blanks.length) {
    final cell = blanks[cursor++];
    board[cell] = solution[cell];
  }
  while (!_solvesLogically(board, hiddenSingles: hiddenSingles) &&
      cursor < blanks.length) {
    final cell = blanks[cursor++];
    board[cell] = solution[cell];
  }
  if (!_solvesLogically(board, hiddenSingles: hiddenSingles)) {
    throw StateError('${source.id} 문제를 단일 후보만으로 풀 수 있게 만들지 못했습니다.');
  }
  return PuzzleLine(
    '$prefix${source.id.substring(0, 11)}',
    source.rating,
    board.join(),
    source.solution,
  );
}

bool _solvesLogically(List<int> puzzle, {required bool hiddenSingles}) {
  final board = List<int>.from(puzzle);
  while (true) {
    var progress = false;
    for (var cell = 0; cell < 81; cell++) {
      if (board[cell] != 0) continue;
      final candidates = _candidates(board, cell);
      if (candidates.length == 1) {
        board[cell] = candidates.single;
        progress = true;
      }
    }
    if (hiddenSingles) {
      for (final unit in _units) {
        for (var number = 1; number <= 9; number++) {
          final cells = unit
              .where(
                (cell) =>
                    board[cell] == 0 &&
                    _candidates(board, cell).contains(number),
              )
              .toList();
          if (cells.length == 1) {
            board[cells.single] = number;
            progress = true;
          }
        }
      }
    }
    if (!progress) break;
  }
  return board.every((value) => value != 0);
}

Set<int> _candidates(List<int> board, int cell) {
  final used = _peers(cell).map((peer) => board[peer]).toSet();
  return {
    for (var n = 1; n <= 9; n++)
      if (!used.contains(n)) n,
  };
}

final _units = <Set<int>>[
  for (var r = 0; r < 9; r++) {for (var c = 0; c < 9; c++) r * 9 + c},
  for (var c = 0; c < 9; c++) {for (var r = 0; r < 9; r++) r * 9 + c},
  for (var br = 0; br < 3; br++)
    for (var bc = 0; bc < 3; bc++)
      {
        for (var r = br * 3; r < br * 3 + 3; r++)
          for (var c = bc * 3; c < bc * 3 + 3; c++) r * 9 + c,
      },
];

Set<int> _peers(int cell) =>
    {for (final unit in _units.where((unit) => unit.contains(cell))) ...unit}
      ..remove(cell);

void _shuffle(List<int> values, int seed) {
  var state = seed & 0x7fffffff;
  for (var i = values.length - 1; i > 0; i--) {
    state = (1103515245 * state + 12345) & 0x7fffffff;
    final j = state % (i + 1);
    final value = values[i];
    values[i] = values[j];
    values[j] = value;
  }
}

List<PuzzleLine> _read(File file) => file
    .readAsLinesSync()
    .where((line) => line.trim().isNotEmpty)
    .map(PuzzleLine.parse)
    .toList();

void _write(File file, List<PuzzleLine> puzzles) => file.writeAsStringSync(
  '${puzzles.map((puzzle) => puzzle.encode()).join('\n')}\n',
);

int _lineCount(File file) =>
    file.readAsLinesSync().where((line) => line.isNotEmpty).length;

class PuzzleLine {
  const PuzzleLine(this.id, this.rating, this.puzzle, this.solution);

  factory PuzzleLine.parse(String line) {
    final fields = line.split('|');
    return PuzzleLine(fields[0], double.parse(fields[1]), fields[2], fields[3]);
  }

  final String id;
  final double rating;
  final String puzzle;
  final String solution;

  String encode() => '$id|$rating|$puzzle|$solution';
}
