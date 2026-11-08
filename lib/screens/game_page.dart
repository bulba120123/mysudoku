import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/game_preferences_store.dart';
import '../data/game_save_store.dart';
import '../data/puzzle_repository.dart';
import '../game/game_history.dart';
import '../game/sudoku_logic.dart';
import '../ui/puzzle_difficulty_label.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    required this.puzzle,
    this.restoredGame,
    this.saveStore,
    this.darkMode = false,
    this.onToggleTheme,
    super.key,
  });

  final SudokuPuzzle puzzle;
  final SavedGame? restoredGame;
  final GameSaveStore? saveStore;
  final bool darkMode;
  final VoidCallback? onToggleTheme;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final List<int> givens;
  late final String solution;
  late List<int> values;
  late List<Set<int>> notes;
  late List<Set<int>> eliminated;
  final undo = <GameSnapshot>[];
  final redo = <GameSnapshot>[];
  Timer? timer;
  Timer? celebrationTimer;
  int? selected;
  int seconds = 0, mistakes = 0;
  bool noteMode = false, paused = false, numberFirstMode = false;
  bool autoRemoveNotes = true;
  bool hapticsEnabled = true;
  bool showTimer = true;
  bool animationsEnabled = true;
  int? pickedNumber;
  final preferencesStore = GamePreferencesStore();
  HintStep? hint;
  Set<int> celebrationCells = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    givens = widget.puzzle.puzzle.split('').map(int.parse).toList();
    solution = widget.puzzle.solution;
    final restored = widget.restoredGame;
    values = restored == null ? [...givens] : [...restored.values];
    notes = restored == null
        ? List.generate(81, (_) => <int>{})
        : restored.notes.map((note) => {...note}).toList();
    eliminated = restored == null
        ? List.generate(81, (_) => <int>{})
        : restored.eliminated.map((values) => {...values}).toList();
    seconds = restored?.seconds ?? 0;
    mistakes = restored?.mistakes ?? 0;
    noteMode = restored?.noteMode ?? false;
    numberFirstMode = restored?.numberFirstMode ?? false;
    pickedNumber = restored?.pickedNumber;
    if (restored != null) {
      undo.addAll(restored.undo.map((snapshot) => snapshot.copy()));
      redo.addAll(restored.redo.map((snapshot) => snapshot.copy()));
    }
    if (widget.saveStore != null) {
      loadGamePreferences(preserveNumberFirst: restored != null);
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !paused && !complete) {
        setState(() => seconds++);
        if (seconds % 5 == 0) saveGame();
      }
    });
    if (restored == null) saveGame();
  }

  Future<void> loadGamePreferences({required bool preserveNumberFirst}) async {
    final preferences = await preferencesStore.load();
    if (!mounted) return;
    setState(() {
      if (!preserveNumberFirst) numberFirstMode = preferences.numberFirstMode;
      autoRemoveNotes = preferences.autoRemoveNotes;
      hapticsEnabled = preferences.haptics;
      showTimer = preferences.showTimer;
      animationsEnabled = preferences.animations;
    });
  }

  Future<void> saveGamePreferences() {
    if (widget.saveStore == null) return Future.value();
    return preferencesStore.save(
      GamePreferences(
        numberFirstMode: numberFirstMode,
        autoRemoveNotes: autoRemoveNotes,
        haptics: hapticsEnabled,
        showTimer: showTimer,
        animations: animationsEnabled,
      ),
    );
  }

  @override
  void dispose() {
    saveGame();
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    celebrationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      saveGame();
    }
  }

  Future<void> saveGame() async {
    final store = widget.saveStore;
    if (store == null || complete) return;
    await store.save(
      SavedGame(
        puzzle: widget.puzzle,
        values: [...values],
        notes: notes.map((note) => {...note}).toList(),
        eliminated: eliminated.map((values) => {...values}).toList(),
        seconds: seconds,
        mistakes: mistakes,
        noteMode: noteMode,
        numberFirstMode: numberFirstMode,
        pickedNumber: pickedNumber,
        undo: undo.map((snapshot) => snapshot.copy()).toList(),
        redo: redo.map((snapshot) => snapshot.copy()).toList(),
      ),
    );
  }

  bool get complete => List.generate(
    81,
    (i) => values[i] == int.parse(solution[i]),
  ).every((x) => x);
  GameSnapshot get snap => GameSnapshot(
    [...values],
    notes.map((x) => {...x}).toList(),
    eliminated.map((x) => {...x}).toList(),
  );
  String get clock =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  void remember() {
    undo.add(snap);
    redo.clear();
  }

  void restore(GameSnapshot s) {
    values = [...s.values];
    notes = s.notes.map((x) => {...x}).toList();
    eliminated = s.eliminated.map((x) => {...x}).toList();
    hint = null;
  }

  void undoMove() {
    if (undo.isEmpty) return;
    setState(() {
      redo.add(snap);
      restore(undo.removeLast());
    });
    saveGame();
  }

  void redoMove() {
    if (redo.isEmpty) return;
    setState(() {
      undo.add(snap);
      restore(redo.removeLast());
    });
    saveGame();
  }

  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    const numberKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpadKeys = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    var index = numberKeys.indexOf(event.logicalKey);
    if (index < 0) index = numpadKeys.indexOf(event.logicalKey);
    if (index >= 0) {
      pressNumber(index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
      erase();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      setState(() => noteMode = !noteMode);
      saveGame();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      undoMove();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyY) {
      redoMove();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      findHint();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => pickedNumber = null);
      return KeyEventResult.handled;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -9,
      LogicalKeyboardKey.arrowDown => 9,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (direction != 0) {
      final current = selected ?? 0;
      var next = current + direction;
      if (direction == -1 && current % 9 == 0) next = current;
      if (direction == 1 && current % 9 == 8) next = current;
      setState(() => selected = next.clamp(0, 80));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void pressNumber(int number) {
    if (paused || numberComplete(number)) return;
    if (!numberFirstMode) {
      enter(number);
      return;
    }
    setState(() {
      pickedNumber = pickedNumber == number ? null : number;
    });
    saveGame();
  }

  void enter(int n) {
    final cell = selected;
    if (cell == null || givens[cell] != 0 || paused || numberComplete(n)) {
      return;
    }
    if (!noteMode && values[cell] == n) return;
    remember();
    setState(() {
      hint = null;
      if (noteMode && values[cell] == 0) {
        notes[cell].contains(n) ? notes[cell].remove(n) : notes[cell].add(n);
      } else if (!noteMode) {
        values[cell] = n;
        notes[cell].clear();
        eliminated[cell].clear();
        if (n != int.parse(solution[cell])) {
          mistakes++;
          if (hapticsEnabled) HapticFeedback.heavyImpact();
        }
        if (n == int.parse(solution[cell])) {
          if (hapticsEnabled) HapticFeedback.selectionClick();
          if (autoRemoveNotes) {
            for (final p in SudokuLogic.peers(cell)) {
              notes[p].remove(n);
            }
          }
          if (numberFirstMode && numberComplete(n)) {
            pickedNumber = _nextIncompleteNumber(n);
          }
        }
      }
    });
    if (!noteMode && n == int.parse(solution[cell])) {
      final completedCells = _completedUnitCells(cell);
      if (completedCells.isNotEmpty) _celebrate(completedCells);
    }
    saveGame();
    if (complete) {
      if (hapticsEnabled) HapticFeedback.mediumImpact();
      widget.saveStore?.clear();
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: TweenAnimationBuilder<double>(
            duration: animationsEnabled
                ? const Duration(milliseconds: 500)
                : Duration.zero,
            tween: Tween(begin: .4, end: 1),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(Icons.auto_awesome, size: 42),
          ),
          title: const Text('완성했습니다!'),
          content: Text('기록 $clock · 실수 $mistakes회'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('보드 보기'),
            ),
          ],
        ),
      );
    }
  }

  Set<int> _completedUnitCells(int cell) {
    final units = SudokuLogic.units.where((unit) => unit.contains(cell));
    final completed = <int>{};
    for (final unit in units) {
      if (unit.every((index) => values[index] == int.parse(solution[index]))) {
        completed.addAll(unit);
      }
    }
    return completed;
  }

  void _celebrate(Set<int> cells) {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
    if (!animationsEnabled) return;
    celebrationTimer?.cancel();
    setState(() => celebrationCells = cells);
    celebrationTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(celebrationCells.clear);
    });
  }

  int? _nextIncompleteNumber(int current) {
    for (var offset = 1; offset <= 9; offset++) {
      final candidate = (current + offset - 1) % 9 + 1;
      if (!numberComplete(candidate)) return candidate;
    }
    return null;
  }

  void tapCell(int cell) {
    setState(() {
      selected = cell;
      hint = null;
    });
    final number = pickedNumber;
    if (numberFirstMode && number != null && givens[cell] == 0) {
      enter(number);
    }
  }

  void erase() {
    final cell = selected;
    if (cell == null ||
        givens[cell] != 0 ||
        (values[cell] == 0 && notes[cell].isEmpty)) {
      return;
    }
    remember();
    setState(() {
      values[cell] = 0;
      notes[cell].clear();
      eliminated[cell].clear();
      hint = null;
    });
    saveGame();
  }

  bool numberComplete(int number) {
    for (var cell = 0; cell < 81; cell++) {
      if (int.parse(solution[cell]) == number && values[cell] != number) {
        return false;
      }
    }
    return true;
  }

  void fillNotes() {
    if (paused) return;
    remember();
    final candidates = SudokuLogic.candidates(values, eliminated: eliminated);
    setState(() {
      for (var cell = 0; cell < 81; cell++) {
        if (values[cell] == 0) notes[cell] = {...?candidates[cell]};
      }
    });
    saveGame();
  }

  void findHint() {
    for (var i = 0; i < 81; i++) {
      if (values[i] != 0 && values[i] != int.parse(solution[i])) {
        hint = HintStep('입력 확인', '빨간 숫자가 정답과 다릅니다. 먼저 수정해 주세요.', {i}, {});
        selected = i;
        setState(() {});
        showHint();
        return;
      }
    }
    final found = SudokuLogic.find(values, eliminated: eliminated);
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원되는 논리 기법으로 다음 단계를 찾지 못했습니다.')),
      );
      return;
    }
    setState(() {
      hint = found;
      selected = found.focus.firstOrNull;
    });
    showHint();
  }

  Future<void> showHint() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint!.technique,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(hint!.text, style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('직접 풀기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: hint!.canApply
                      ? () {
                          Navigator.pop(sheetContext);
                          applyHint();
                        }
                      : null,
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void applyHint() {
    final h = hint!;
    remember();
    setState(() {
      if (h.cell != null) {
        values[h.cell!] = h.number!;
        notes[h.cell!].clear();
        eliminated[h.cell!].clear();
        for (final p in SudokuLogic.peers(h.cell!)) {
          notes[p].remove(h.number);
        }
      } else {
        for (final e in h.removals.entries) {
          notes[e.key].removeAll(e.value);
          eliminated[e.key].addAll(e.value);
        }
      }
      hint = null;
    });
    saveGame();
  }

  Future<void> showGameSettings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .85,
      child: StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '게임 설정',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('숫자 우선 입력'),
                subtitle: const Text('숫자를 먼저 고른 뒤 여러 칸에 연속으로 입력합니다.'),
                value: numberFirstMode,
                onChanged: (enabled) {
                  setState(() {
                    numberFirstMode = enabled;
                    if (!enabled) pickedNumber = null;
                  });
                  setSheetState(() {});
                  saveGame();
                  saveGamePreferences();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('후보 자동 제거'),
                subtitle: const Text('숫자를 확정하면 관련 칸의 같은 후보를 지웁니다.'),
                value: autoRemoveNotes,
                onChanged: (enabled) {
                  setState(() => autoRemoveNotes = enabled);
                  setSheetState(() {});
                  saveGamePreferences();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('햅틱'),
                value: hapticsEnabled,
                onChanged: (enabled) {
                  setState(() => hapticsEnabled = enabled);
                  setSheetState(() {});
                  saveGamePreferences();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('타이머 표시'),
                value: showTimer,
                onChanged: (enabled) {
                  setState(() => showTimer = enabled);
                  setSheetState(() {});
                  saveGamePreferences();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('애니메이션'),
                value: animationsEnabled,
                onChanged: (enabled) {
                  setState(() => animationsEnabled = enabled);
                  setSheetState(() {});
                  saveGamePreferences();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('다크 모드'),
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: widget.onToggleTheme == null
                    ? null
                    : (_) {
                        widget.onToggleTheme!();
                        setSheetState(() {});
                      },
              ),
              const Divider(height: 28),
              const Text(
                '키보드: 숫자 1–9 · 방향키 이동 · N 메모 · H 힌트\n'
                'Ctrl+Z 실행 취소 · Ctrl+Y 다시 실행 · Esc 숫자 해제',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Focus(
      autofocus: true,
      onKeyEvent: handleKey,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  header(),
                  const SizedBox(height: 12),
                  board(),
                  const SizedBox(height: 22),
                  toolbar(),
                  const SizedBox(height: 18),
                  numberPad(),
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Sudoku Exchange · 오프라인 문제',
                      style: TextStyle(color: Color(0xff8a8f94), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget header() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 480;
      final density = compact ? VisualDensity.compact : VisualDensity.standard;
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '홈으로',
              visualDensity: density,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '나의 스도쿠',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 18 : 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    compact
                        ? widget.puzzle.difficulty.label
                        : '${widget.puzzle.difficulty.label} · ${widget.puzzle.id.substring(0, 6)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xff6f777e),
                      fontSize: compact ? 11 : 14,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  showTimer ? clock : '',
                  semanticsLabel: showTimer ? '경과 시간 $clock' : '타이머 숨김',
                  style: TextStyle(
                    fontSize: compact ? 14 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '실수 $mistakes회',
                  style: TextStyle(
                    color: const Color(0xffb4514a),
                    fontSize: compact ? 10 : 13,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: '게임 설정',
              visualDensity: density,
              onPressed: showGameSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: paused ? '계속하기' : '일시 정지',
              visualDensity: density,
              onPressed: () {
                setState(() => paused = !paused);
                saveGame();
              },
              icon: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget board() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xff1b2631) : Colors.white,
              border: Border.all(
                color: dark ? const Color(0xff91a8ba) : const Color(0xff17324d),
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
              ),
              itemCount: 81,
              itemBuilder: (_, i) => cell(i),
            ),
          ),
          if (paused)
            Positioned.fill(
              child: ColoredBox(
                color: dark ? const Color(0xff111820) : const Color(0xfff7f5ef),
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () => setState(() => paused = false),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('계속하기'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget cell(int i) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = i ~/ 9,
        c = i % 9,
        sr = selected == null ? -1 : selected! ~/ 9,
        sc = selected == null ? -1 : selected! % 9;
    final sameUnit =
        selected != null &&
        (r == sr || c == sc || (r ~/ 3 == sr ~/ 3 && c ~/ 3 == sc ~/ 3));
    final selectedValue = selected == null ? 0 : values[selected!];
    Color bg = sameUnit
        ? (dark ? const Color(0xff283b49) : const Color(0xffeaf0f4))
        : (dark ? const Color(0xff1b2631) : Colors.white);
    if (selectedValue != 0 && values[i] == selectedValue) {
      bg = dark ? const Color(0xff31546a) : const Color(0xffd6e5ee);
    }
    if (celebrationCells.contains(i)) {
      bg = dark ? const Color(0xff285c48) : const Color(0xffccebdc);
    }
    if (hint?.affected.contains(i) ?? false) {
      bg = dark ? const Color(0xff704d2b) : const Color(0xffffe4c4);
    }
    if (hint?.focus.contains(i) ?? false) {
      bg = dark ? const Color(0xff765f22) : const Color(0xffffd77a);
    }
    if (selected == i) {
      bg = dark ? const Color(0xff3f718c) : const Color(0xffaed0e3);
    }
    final value = values[i],
        wrong = value != 0 && value != int.parse(solution[i]);
    final description = value != 0
        ? '${givens[i] != 0 ? '주어진 숫자' : '입력 숫자'} $value${wrong ? ', 오답' : ''}'
        : notes[i].isEmpty
        ? '빈칸'
        : '후보 ${notes[i].toList()..sort()}';
    return Semantics(
      key: ValueKey('semantics-cell-$i'),
      label: '${r + 1}행 ${c + 1}열, $description',
      button: true,
      selected: selected == i,
      child: InkWell(
        key: ValueKey('cell-$i'),
        onTap: () => tapCell(i),
        child: AnimatedContainer(
          duration: animationsEnabled
              ? const Duration(milliseconds: 160)
              : Duration.zero,
          key: ValueKey('cell-background-$i'),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              right: BorderSide(
                color: dark ? const Color(0xff718594) : const Color(0xff75818b),
                width: c == 2 || c == 5 ? 2 : (c == 8 ? 0 : .45),
              ),
              bottom: BorderSide(
                color: dark ? const Color(0xff718594) : const Color(0xff75818b),
                width: r == 2 || r == 5 ? 2 : (r == 8 ? 0 : .45),
              ),
            ),
          ),
          child: value != 0
              ? Center(
                  child: Text(
                    key: ValueKey('value-$i'),
                    '$value',
                    style: TextStyle(
                      fontSize: 24,
                      decoration: wrong ? TextDecoration.underline : null,
                      decorationThickness: wrong ? 2.5 : null,
                      fontWeight: givens[i] != 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: wrong
                          ? const Color(0xffc43d36)
                          : (selectedValue != 0 && value == selectedValue
                                ? (dark
                                      ? const Color(0xff8ed6ff)
                                      : const Color(0xff005d91))
                                : givens[i] != 0
                                ? (dark
                                      ? const Color(0xffeef4f7)
                                      : const Color(0xff202a33))
                                : (dark
                                      ? const Color(0xff73c8f5)
                                      : const Color(0xff2073a5))),
                    ),
                  ),
                )
              : noteGrid(i, selectedValue, dark),
        ),
      ),
    );
  }

  Widget noteGrid(int cell, int selectedValue, bool dark) => Padding(
    padding: const EdgeInsets.all(1.5),
    child: Column(
      children: List.generate(
        3,
        (row) => Expanded(
          child: Row(
            children: List.generate(3, (column) {
              final number = row * 3 + column + 1;
              final visible = notes[cell].contains(number);
              final highlighted = visible && number == selectedValue;
              return Expanded(
                child: Container(
                  key: ValueKey('note-background-$cell-$number'),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? (dark
                              ? const Color(0xff397a9d)
                              : const Color(0xff73b7dc))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    key: ValueKey('note-$cell-$number'),
                    visible ? '$number' : '',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: highlighted
                          ? FontWeight.w900
                          : FontWeight.w500,
                      color: highlighted
                          ? (dark
                                ? const Color(0xffd8f2ff)
                                : const Color(0xff073f62))
                          : (dark
                                ? const Color(0xffa8c0cf)
                                : const Color(0xff496477)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );

  Widget toolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final children = <Widget>[
        tool(Icons.undo_rounded, '실행 취소', undo.isEmpty ? null : undoMove),
        tool(Icons.redo_rounded, '다시 실행', redo.isEmpty ? null : redoMove),
        tool(Icons.edit_outlined, noteMode ? '메모 켬' : '메모', () {
          setState(() => noteMode = !noteMode);
          saveGame();
        }, active: noteMode),
        tool(Icons.backspace_outlined, '지우기', erase),
        tool(Icons.auto_awesome_outlined, '후보 채우기', fillNotes),
        tool(Icons.lightbulb_outline, '힌트', findHint),
      ];
      if (constraints.maxWidth < 480 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        return GridView.count(
          crossAxisCount: 3,
          childAspectRatio: largeText ? 1.25 : 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      );
    },
  );

  Widget tool(
    IconData icon,
    String label,
    VoidCallback? tap, {
    bool active = false,
  }) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xff2f8fbd)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xff263541)
                        : const Color(0xffe8ecec)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: active
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xffc7d8e3)
                        : const Color(0xff334a5d)),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10.5)),
        ],
      ),
    ),
  );

  Widget numberPad() => Row(
    children: List.generate(9, (i) {
      final completed = numberComplete(i + 1);
      final picked = numberFirstMode && pickedNumber == i + 1;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i == 8 ? 0 : 5),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              key: ValueKey('number-key-${i + 1}'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: completed
                    ? const Color(0xff69747b)
                    : (picked
                          ? const Color(0xff2f8fbd)
                          : const Color(0xff17324d)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: completed ? null : () => pressNumber(i + 1),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}
