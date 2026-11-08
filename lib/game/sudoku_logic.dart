class HintStep {
  const HintStep(
    this.technique,
    this.text,
    this.focus,
    this.affected, {
    this.cell,
    this.number,
    this.removals = const {},
  });
  final String technique, text;
  final Set<int> focus, affected;
  final int? cell, number;
  final Map<int, Set<int>> removals;
  bool get canApply => cell != null || removals.isNotEmpty;
}

class SudokuLogic {
  static final units = <Set<int>>[
    for (var r = 0; r < 9; r++) {for (var c = 0; c < 9; c++) r * 9 + c},
    for (var c = 0; c < 9; c++) {for (var r = 0; r < 9; r++) r * 9 + c},
    for (var br = 0; br < 3; br++)
      for (var bc = 0; bc < 3; bc++)
        {
          for (var r = br * 3; r < br * 3 + 3; r++)
            for (var c = bc * 3; c < bc * 3 + 3; c++) r * 9 + c,
        },
  ];
  static Set<int> peers(int cell) =>
      {for (final u in units.where((u) => u.contains(cell))) ...u}
        ..remove(cell);

  static List<int> solve(List<int> puzzle) {
    final board = [...puzzle];
    bool search() {
      var best = -1;
      Set<int>? options;
      for (var i = 0; i < 81; i++) {
        if (board[i] != 0) continue;
        final available = {
          for (var n = 1; n <= 9; n++)
            if (!peers(i).map((p) => board[p]).contains(n)) n,
        };
        if (available.isEmpty) return false;
        if (options == null || available.length < options.length) {
          best = i;
          options = available;
        }
      }
      if (best == -1) return true;
      for (final n in options!) {
        board[best] = n;
        if (search()) return true;
      }
      board[best] = 0;
      return false;
    }

    if (!search()) throw StateError('해답이 없는 스도쿠 문제입니다.');
    return board;
  }

  static Map<int, Set<int>> candidates(
    List<int> b, {
    List<Set<int>>? eliminated,
  }) => {
    for (var i = 0; i < 81; i++)
      if (b[i] == 0)
        i: {
          for (var n = 1; n <= 9; n++)
            if (!peers(i).map((p) => b[p]).contains(n) &&
                !(eliminated?[i].contains(n) ?? false))
              n,
        },
  };
  static String name(int i) => '${i ~/ 9 + 1}행 ${i % 9 + 1}열';

  static HintStep? find(List<int> board, {List<Set<int>>? eliminated}) {
    final c = candidates(board, eliminated: eliminated);
    for (final e in c.entries) {
      if (e.value.length == 1) {
        return HintStep(
          'Naked Single · 유일 후보',
          '${name(e.key)}에는 ${e.value.first}만 들어갈 수 있습니다.',
          {e.key},
          {},
          cell: e.key,
          number: e.value.first,
        );
      }
    }
    for (final u in units) {
      for (var n = 1; n <= 9; n++) {
        final spots = u.where((i) => c[i]?.contains(n) ?? false).toList();
        if (spots.length == 1) {
          return HintStep(
            'Hidden Single · 숨은 단일 후보',
            '이 구역에서 $n이 들어갈 수 있는 칸은 ${name(spots.first)}뿐입니다.',
            u,
            {spots.first},
            cell: spots.first,
            number: n,
          );
        }
      }
    }
    for (var box = 18; box < 27; box++) {
      for (var n = 1; n <= 9; n++) {
        final u = units[box],
            spots = u.where((i) => c[i]?.contains(n) ?? false).toList();
        if (spots.length < 2) continue;
        final rows = spots.map((i) => i ~/ 9).toSet(),
            cols = spots.map((i) => i % 9).toSet();
        Set<int> targets = {};
        if (rows.length == 1) {
          targets = units[rows.first]
              .where((i) => !u.contains(i) && (c[i]?.contains(n) ?? false))
              .toSet();
        }
        if (cols.length == 1) {
          targets = units[9 + cols.first]
              .where((i) => !u.contains(i) && (c[i]?.contains(n) ?? false))
              .toSet();
        }
        if (targets.isNotEmpty) {
          return HintStep(
            'Locked Candidates · Pointing',
            '박스 안의 $n 후보가 한 줄에 모였습니다. 주황색 칸에서 $n을 제거할 수 있습니다.',
            spots.toSet(),
            targets,
            removals: {
              for (final t in targets) t: {n},
            },
          );
        }
      }
    }
    for (final u in units) {
      final pairs = u.where((i) => c[i]?.length == 2).toList();
      for (var a = 0; a < pairs.length; a++) {
        for (var b = a + 1; b < pairs.length; b++) {
          final nums = c[pairs[a]]!;
          if (nums.length != c[pairs[b]]!.length ||
              !nums.containsAll(c[pairs[b]]!)) {
            continue;
          }
          final removals = <int, Set<int>>{};
          for (final i in u.where((i) => i != pairs[a] && i != pairs[b])) {
            final hits = c[i]?.intersection(nums) ?? {};
            if (hits.isNotEmpty) removals[i] = hits;
          }
          if (removals.isNotEmpty) {
            return HintStep(
              'Naked Pair · 드러난 쌍',
              '${name(pairs[a])}과 ${name(pairs[b])}의 후보가 ${nums.join(', ')}로 같습니다. 다른 칸에서 이 후보를 제거할 수 있습니다.',
              {pairs[a], pairs[b]},
              removals.keys.toSet(),
              removals: removals,
            );
          }
        }
      }
    }
    for (var n = 1; n <= 9; n++) {
      final rc = <int, List<int>>{
        for (var r = 0; r < 9; r++)
          if ([
                for (var col = 0; col < 9; col++)
                  if (c[r * 9 + col]?.contains(n) ?? false) col,
              ].length ==
              2)
            r: [
              for (var col = 0; col < 9; col++)
                if (c[r * 9 + col]?.contains(n) ?? false) col,
            ],
      };
      final rows = rc.keys.toList();
      for (var a = 0; a < rows.length; a++) {
        for (var b = a + 1; b < rows.length; b++) {
          final ca = rc[rows[a]]!, cb = rc[rows[b]]!;
          if (ca[0] != cb[0] || ca[1] != cb[1]) continue;
          final removals = <int, Set<int>>{};
          for (var r = 0; r < 9; r++) {
            if (r != rows[a] && r != rows[b]) {
              for (final col in ca) {
                final i = r * 9 + col;
                if (c[i]?.contains(n) ?? false) {
                  removals[i] = {n};
                }
              }
            }
          }
          if (removals.isNotEmpty) {
            return HintStep(
              'X-Wing · 엑스윙',
              '$n 후보가 두 행의 같은 두 열에만 있어 X-Wing을 이룹니다. 주황색 칸의 $n 후보를 제거할 수 있습니다.',
              {
                rows[a] * 9 + ca[0],
                rows[a] * 9 + ca[1],
                rows[b] * 9 + ca[0],
                rows[b] * 9 + ca[1],
              },
              removals.keys.toSet(),
              removals: removals,
            );
          }
        }
      }
    }
    return AdvancedHintEngine.find(c);
  }
}

class AdvancedHintEngine {
  static HintStep? find(Map<int, Set<int>> candidates) =>
      _claiming(candidates) ??
      _nakedSubset(candidates, 3) ??
      _hiddenSubset(candidates, 2) ??
      _hiddenSubset(candidates, 3) ??
      _nakedSubset(candidates, 4) ??
      _hiddenSubset(candidates, 4) ??
      _fish(candidates, 2) ??
      _skyscraper(candidates) ??
      _twoStringKite(candidates) ??
      _xyWing(candidates) ??
      _xyzWing(candidates) ??
      _fish(candidates, 3) ??
      _fish(candidates, 4) ??
      _simpleColoring(candidates);

  static HintStep? _claiming(Map<int, Set<int>> c) {
    for (var unitIndex = 0; unitIndex < 18; unitIndex++) {
      final unit = SudokuLogic.units[unitIndex];
      for (var number = 1; number <= 9; number++) {
        final spots = unit
            .where((cell) => c[cell]?.contains(number) ?? false)
            .toList();
        if (spots.length < 2) continue;
        final boxes = spots.map(_box).toSet();
        if (boxes.length != 1) continue;
        final boxUnit = SudokuLogic.units[18 + boxes.single];
        final targets = boxUnit
            .where(
              (cell) =>
                  !unit.contains(cell) && (c[cell]?.contains(number) ?? false),
            )
            .toSet();
        if (targets.isNotEmpty) {
          return HintStep(
            'Locked Candidates · Claiming',
            '이 줄의 $number 후보가 한 박스에만 있습니다. 같은 박스의 다른 $number 후보를 제거할 수 있습니다.',
            spots.toSet(),
            targets,
            removals: {
              for (final cell in targets) cell: {number},
            },
          );
        }
      }
    }
    return null;
  }

  static HintStep? _nakedSubset(Map<int, Set<int>> c, int size) {
    for (final unit in SudokuLogic.units) {
      final cells = unit
          .where(
            (cell) => (c[cell]?.length ?? 0) >= 2 && c[cell]!.length <= size,
          )
          .toList();
      for (final selected in _combinations(cells, size)) {
        final numbers = <int>{};
        for (final cell in selected) {
          numbers.addAll(c[cell]!);
        }
        if (numbers.length != size) continue;
        final removals = <int, Set<int>>{};
        for (final cell in unit.where((cell) => !selected.contains(cell))) {
          final hits = c[cell]?.intersection(numbers) ?? {};
          if (hits.isNotEmpty) removals[cell] = hits;
        }
        if (removals.isNotEmpty) {
          return HintStep(
            'Naked ${_subsetName(size)} · 드러난 ${_koreanSize(size)}',
            '${selected.map(SudokuLogic.name).join(', ')}의 후보 ${numbers.join(', ')}가 묶여 있어 같은 구역의 다른 칸에서 제거할 수 있습니다.',
            selected.toSet(),
            removals.keys.toSet(),
            removals: removals,
          );
        }
      }
    }
    return null;
  }

  static HintStep? _hiddenSubset(Map<int, Set<int>> c, int size) {
    for (final unit in SudokuLogic.units) {
      for (final numbers in _combinations(
        List.generate(9, (i) => i + 1),
        size,
      )) {
        final cells = unit
            .where(
              (cell) =>
                  numbers.any((number) => c[cell]?.contains(number) ?? false),
            )
            .toSet();
        if (cells.length != size ||
            numbers.any(
              (number) => !cells.any((cell) => c[cell]!.contains(number)),
            )) {
          continue;
        }
        final keep = numbers.toSet();
        final removals = <int, Set<int>>{};
        for (final cell in cells) {
          final extras = c[cell]!.difference(keep);
          if (extras.isNotEmpty) removals[cell] = extras;
        }
        if (removals.isNotEmpty) {
          return HintStep(
            'Hidden ${_subsetName(size)} · 숨은 ${_koreanSize(size)}',
            '숫자 ${numbers.join(', ')}가 이 구역의 ${cells.length}칸에만 들어갈 수 있어 다른 후보를 제거할 수 있습니다.',
            cells,
            cells,
            removals: removals,
          );
        }
      }
    }
    return null;
  }

  static HintStep? _fish(Map<int, Set<int>> c, int size) {
    for (var number = 1; number <= 9; number++) {
      for (final rowsAsBase in [true, false]) {
        final positions = <int, Set<int>>{};
        for (var base = 0; base < 9; base++) {
          final covers = <int>{};
          for (var cover = 0; cover < 9; cover++) {
            final cell = rowsAsBase ? base * 9 + cover : cover * 9 + base;
            if (c[cell]?.contains(number) ?? false) covers.add(cover);
          }
          if (covers.length >= 2 && covers.length <= size) {
            positions[base] = covers;
          }
        }
        for (final bases in _combinations(positions.keys.toList(), size)) {
          final covers = <int>{};
          for (final base in bases) {
            covers.addAll(positions[base]!);
          }
          if (covers.length != size) continue;
          final removals = <int, Set<int>>{};
          for (var base = 0; base < 9; base++) {
            if (bases.contains(base)) continue;
            for (final cover in covers) {
              final cell = rowsAsBase ? base * 9 + cover : cover * 9 + base;
              if (c[cell]?.contains(number) ?? false) removals[cell] = {number};
            }
          }
          if (removals.isNotEmpty) {
            final focus = <int>{};
            for (final base in bases) {
              for (final cover in positions[base]!) {
                focus.add(rowsAsBase ? base * 9 + cover : cover * 9 + base);
              }
            }
            final technique = switch (size) {
              2 => 'X-Wing · 엑스윙',
              3 => 'Swordfish · 소드피시',
              _ => 'Jellyfish · 젤리피시',
            };
            return HintStep(
              technique,
              '$number 후보가 $size개의 ${rowsAsBase ? '행' : '열'}과 $size개의 ${rowsAsBase ? '열' : '행'}에 갇혀 있어 바깥 후보를 제거할 수 있습니다.',
              focus,
              removals.keys.toSet(),
              removals: removals,
            );
          }
        }
      }
    }
    return null;
  }

  static HintStep? _skyscraper(Map<int, Set<int>> c) {
    for (var number = 1; number <= 9; number++) {
      for (final rowsAsBase in [true, false]) {
        final pairs = <int, List<int>>{};
        for (var base = 0; base < 9; base++) {
          final positions = <int>[];
          for (var cover = 0; cover < 9; cover++) {
            final cell = rowsAsBase ? base * 9 + cover : cover * 9 + base;
            if (c[cell]?.contains(number) ?? false) positions.add(cover);
          }
          if (positions.length == 2) pairs[base] = positions;
        }
        final bases = pairs.keys.toList();
        for (var a = 0; a < bases.length; a++) {
          for (var b = a + 1; b < bases.length; b++) {
            final shared = pairs[bases[a]]!.toSet().intersection(
              pairs[bases[b]]!.toSet(),
            );
            if (shared.length != 1) continue;
            final roofA = pairs[bases[a]]!.firstWhere(
              (p) => p != shared.single,
            );
            final roofB = pairs[bases[b]]!.firstWhere(
              (p) => p != shared.single,
            );
            final cellA = rowsAsBase
                ? bases[a] * 9 + roofA
                : roofA * 9 + bases[a];
            final cellB = rowsAsBase
                ? bases[b] * 9 + roofB
                : roofB * 9 + bases[b];
            final targets = SudokuLogic.peers(cellA)
                .intersection(SudokuLogic.peers(cellB))
                .where((cell) => c[cell]?.contains(number) ?? false)
                .toSet();
            targets.removeAll({cellA, cellB});
            if (targets.isNotEmpty) {
              final sharedA = rowsAsBase
                  ? bases[a] * 9 + shared.single
                  : shared.single * 9 + bases[a];
              final sharedB = rowsAsBase
                  ? bases[b] * 9 + shared.single
                  : shared.single * 9 + bases[b];
              return HintStep(
                'Skyscraper · 스카이스크래퍼',
                '$number의 두 강한 연결이 한 줄을 공유합니다. 두 지붕을 모두 보는 칸에서 $number를 제거할 수 있습니다.',
                {sharedA, sharedB, cellA, cellB},
                targets,
                removals: {
                  for (final cell in targets) cell: {number},
                },
              );
            }
          }
        }
      }
    }
    return null;
  }

  static HintStep? _twoStringKite(Map<int, Set<int>> c) {
    for (var number = 1; number <= 9; number++) {
      final rowPairs = <List<int>>[];
      final colPairs = <List<int>>[];
      for (var row = 0; row < 9; row++) {
        final cells = [
          for (var col = 0; col < 9; col++)
            if (c[row * 9 + col]?.contains(number) ?? false) row * 9 + col,
        ];
        if (cells.length == 2) rowPairs.add(cells);
      }
      for (var col = 0; col < 9; col++) {
        final cells = [
          for (var row = 0; row < 9; row++)
            if (c[row * 9 + col]?.contains(number) ?? false) row * 9 + col,
        ];
        if (cells.length == 2) colPairs.add(cells);
      }
      for (final rowPair in rowPairs) {
        for (final colPair in colPairs) {
          for (final rowBase in rowPair) {
            for (final colBase in colPair) {
              if (rowBase == colBase || _box(rowBase) != _box(colBase)) {
                continue;
              }
              final rowRoof = rowPair.firstWhere((cell) => cell != rowBase);
              final colRoof = colPair.firstWhere((cell) => cell != colBase);
              final targets = SudokuLogic.peers(rowRoof)
                  .intersection(SudokuLogic.peers(colRoof))
                  .where((cell) => c[cell]?.contains(number) ?? false)
                  .toSet();
              targets.removeAll({...rowPair, ...colPair});
              if (targets.isNotEmpty) {
                return HintStep(
                  'Two-String Kite · 투 스트링 카이트',
                  '$number의 행과 열 강한 연결이 한 박스에서 만납니다. 반대쪽 두 후보를 모두 보는 칸에서 $number를 제거할 수 있습니다.',
                  {...rowPair, ...colPair},
                  targets,
                  removals: {
                    for (final cell in targets) cell: {number},
                  },
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  static HintStep? _xyWing(Map<int, Set<int>> c) {
    final bivalue = c.keys.where((cell) => c[cell]!.length == 2).toList();
    for (final pivot in bivalue) {
      final pivotValues = c[pivot]!;
      final wings = bivalue
          .where(
            (cell) => cell != pivot && SudokuLogic.peers(pivot).contains(cell),
          )
          .toList();
      for (var a = 0; a < wings.length; a++) {
        for (var b = a + 1; b < wings.length; b++) {
          final first = c[wings[a]]!, second = c[wings[b]]!;
          final firstPivot = first.intersection(pivotValues);
          final secondPivot = second.intersection(pivotValues);
          final common = first.intersection(second).difference(pivotValues);
          if (firstPivot.length != 1 ||
              secondPivot.length != 1 ||
              firstPivot.first == secondPivot.first ||
              common.length != 1) {
            continue;
          }
          final number = common.single;
          final targets = SudokuLogic.peers(wings[a])
              .intersection(SudokuLogic.peers(wings[b]))
              .where(
                (cell) => cell != pivot && (c[cell]?.contains(number) ?? false),
              )
              .toSet();
          if (targets.isNotEmpty) {
            return HintStep(
              'XY-Wing · XY 윙',
              '${SudokuLogic.name(pivot)}를 축으로 한 XY-Wing입니다. 두 날개를 모두 보는 칸에서 $number를 제거할 수 있습니다.',
              {pivot, wings[a], wings[b]},
              targets,
              removals: {
                for (final cell in targets) cell: {number},
              },
            );
          }
        }
      }
    }
    return null;
  }

  static HintStep? _xyzWing(Map<int, Set<int>> c) {
    final pivots = c.keys.where((cell) => c[cell]!.length == 3);
    final bivalue = c.keys.where((cell) => c[cell]!.length == 2).toList();
    for (final pivot in pivots) {
      final wings = bivalue
          .where(
            (cell) =>
                SudokuLogic.peers(pivot).contains(cell) &&
                c[pivot]!.containsAll(c[cell]!),
          )
          .toList();
      for (var a = 0; a < wings.length; a++) {
        for (var b = a + 1; b < wings.length; b++) {
          if ({...c[wings[a]]!, ...c[wings[b]]!}.length != 3) continue;
          final common = c[pivot]!
              .intersection(c[wings[a]]!)
              .intersection(c[wings[b]]!);
          if (common.length != 1) continue;
          final number = common.single;
          final targets = SudokuLogic.peers(pivot)
              .intersection(SudokuLogic.peers(wings[a]))
              .intersection(SudokuLogic.peers(wings[b]))
              .where((cell) => (c[cell]?.contains(number) ?? false))
              .toSet();
          targets.removeAll({pivot, wings[a], wings[b]});
          if (targets.isNotEmpty) {
            return HintStep(
              'XYZ-Wing · XYZ 윙',
              '세 칸의 후보 관계로 인해 이 세 칸 중 하나에는 반드시 $number가 들어갑니다. 모두를 보는 칸에서 $number를 제거할 수 있습니다.',
              {pivot, wings[a], wings[b]},
              targets,
              removals: {
                for (final cell in targets) cell: {number},
              },
            );
          }
        }
      }
    }
    return null;
  }

  static HintStep? _simpleColoring(Map<int, Set<int>> c) {
    for (var number = 1; number <= 9; number++) {
      final graph = <int, Set<int>>{};
      for (final unit in SudokuLogic.units) {
        final spots = unit
            .where((cell) => c[cell]?.contains(number) ?? false)
            .toList();
        if (spots.length == 2) {
          graph.putIfAbsent(spots[0], () => {}).add(spots[1]);
          graph.putIfAbsent(spots[1], () => {}).add(spots[0]);
        }
      }
      final visited = <int>{};
      for (final start in graph.keys) {
        if (!visited.add(start)) continue;
        final colors = <int, int>{start: 0};
        final queue = <int>[start];
        while (queue.isNotEmpty) {
          final cell = queue.removeAt(0);
          for (final next in graph[cell]!) {
            if (!colors.containsKey(next)) {
              colors[next] = 1 - colors[cell]!;
              visited.add(next);
              queue.add(next);
            }
          }
        }
        if (colors.length < 4) continue;
        for (final color in [0, 1]) {
          final nodes = colors.entries
              .where((entry) => entry.value == color)
              .map((entry) => entry.key)
              .toList();
          final conflict = nodes.any(
            (cell) => nodes.any(
              (other) =>
                  cell != other && SudokuLogic.peers(cell).contains(other),
            ),
          );
          if (conflict) {
            return HintStep(
              'Simple Coloring · 색상 모순',
              '$number 후보의 같은 색 두 칸이 서로 충돌하므로 그 색의 후보는 모두 제거됩니다.',
              colors.keys.toSet(),
              nodes.toSet(),
              removals: {
                for (final cell in nodes) cell: {number},
              },
            );
          }
        }
        final color0 = colors.entries
            .where((entry) => entry.value == 0)
            .map((entry) => entry.key)
            .toSet();
        final color1 = colors.entries
            .where((entry) => entry.value == 1)
            .map((entry) => entry.key)
            .toSet();
        final targets = c.keys.where((cell) {
          if (colors.containsKey(cell) || !c[cell]!.contains(number)) {
            return false;
          }
          final peers = SudokuLogic.peers(cell);
          return peers.intersection(color0).isNotEmpty &&
              peers.intersection(color1).isNotEmpty;
        }).toSet();
        if (targets.isNotEmpty) {
          return HintStep(
            'Simple Coloring · 색상 함정',
            '두 색의 $number 후보를 모두 보는 칸에서는 $number가 될 수 없습니다.',
            colors.keys.toSet(),
            targets,
            removals: {
              for (final cell in targets) cell: {number},
            },
          );
        }
      }
    }
    return null;
  }

  static int _box(int cell) => (cell ~/ 9) ~/ 3 * 3 + (cell % 9) ~/ 3;

  static Iterable<List<T>> _combinations<T>(
    List<T> values,
    int size, [
    int start = 0,
    List<T>? prefix,
  ]) sync* {
    final selected = prefix ?? <T>[];
    if (selected.length == size) {
      yield List<T>.from(selected);
      return;
    }
    for (var i = start; i <= values.length - (size - selected.length); i++) {
      selected.add(values[i]);
      yield* _combinations(values, size, i + 1, selected);
      selected.removeLast();
    }
  }

  static String _subsetName(int size) => switch (size) {
    2 => 'Pair',
    3 => 'Triple',
    _ => 'Quad',
  };
  static String _koreanSize(int size) => switch (size) {
    2 => '쌍',
    3 => '세 쌍',
    _ => '네 쌍',
  };
}
