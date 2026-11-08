import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/puzzle_repository.dart';
import 'package:sudoku/game/sudoku_logic.dart';
import 'package:sudoku/main.dart';

const puzzleText =
    '050703060007000800000816000000030000005000100730040086906000204840572093000409000';

SudokuPuzzle testPuzzle() {
  final solution = SudokuLogic.solve(
    puzzleText.split('').map(int.parse).toList(),
  ).join();
  return SudokuPuzzle(
    id: '0000183b305c',
    difficulty: PuzzleDifficulty.easy,
    rating: 1.2,
    puzzle: puzzleText,
    solution: solution,
  );
}

Future<void> pumpGame(WidgetTester tester) =>
    tester.pumpWidget(MaterialApp(home: GamePage(puzzle: testPuzzle())));

void main() {
  testWidgets('홈 화면에 여섯 가지 난이도를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(enablePersistence: false)),
    );

    expect(find.text('나의 스도쿠'), findsOneWidget);
    expect(find.text('입문'), findsOneWidget);
    expect(find.text('쉬움'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('어려움'), findsOneWidget);
    expect(find.text('전문가'), findsOneWidget);
    expect(find.text('마스터'), findsOneWidget);
  });

  testWidgets('숫자키로 입력하고 실행 취소해도 실수 횟수를 유지한다', (tester) async {
    final answer = SudokuLogic.solve(
      puzzleText.split('').map(int.parse).toList(),
    );
    final wrongNumber = answer.first == 1 ? 2 : 1;
    final key = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ][wrongNumber - 1];

    await pumpGame(tester);
    await tester.tap(find.byKey(const ValueKey('cell-0')));
    await tester.sendKeyEvent(key);
    await tester.pump();
    expect(find.text('실수 1회'), findsOneWidget);

    await tester.sendKeyEvent(key);
    await tester.pump();
    expect(find.text('실수 1회'), findsOneWidget);

    await tester.ensureVisible(find.text('실행 취소'));
    await tester.tap(find.text('실행 취소'));
    await tester.pump();
    expect(find.text('실수 1회'), findsOneWidget);
  });

  testWidgets('선택 숫자와 같은 후보 메모의 작은 칸과 글자색을 강조한다', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byKey(const ValueKey('cell-0')));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('cell-1')));
    await tester.pump();

    final background = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('cell-background-0')),
    );
    final decoration = background.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xffeaf0f4));

    final noteBackground = tester.widget<Container>(
      find.byKey(const ValueKey('note-background-0-5')),
    );
    final noteDecoration = noteBackground.decoration! as BoxDecoration;
    expect(noteDecoration.color, const Color(0xff73b7dc));

    final note = tester.widget<Text>(find.byKey(const ValueKey('note-0-5')));
    expect(note.style?.color, const Color(0xff073f62));
    expect(note.style?.fontWeight, FontWeight.w900);
  });

  testWidgets('후보 자동 채우기가 현재 가능한 숫자를 메모한다', (tester) async {
    final board = puzzleText.split('').map(int.parse).toList();
    final candidate = SudokuLogic.candidates(board)[0]!.first;
    await pumpGame(tester);

    await tester.ensureVisible(find.text('후보 채우기'));
    await tester.tap(find.text('후보 채우기'));
    await tester.pump();

    final note = tester.widget<Text>(find.byKey(ValueKey('note-0-$candidate')));
    expect(note.data, '$candidate');
  });

  testWidgets('다크 모드에서 보드 전용 색상을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: GamePage(puzzle: testPuzzle()),
      ),
    );

    final background = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('cell-background-0')),
    );
    final decoration = background.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xff1b2631));
  });

  testWidgets('숫자 우선 모드에서 같은 숫자를 여러 칸에 연속 입력한다', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('숫자 우선 입력'));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('number-key-1')));
    await tester.tap(find.byKey(const ValueKey('number-key-1')));
    await tester.ensureVisible(find.byKey(const ValueKey('cell-0')));
    await tester.tap(find.byKey(const ValueKey('cell-0')));
    await tester.tap(find.byKey(const ValueKey('cell-2')));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('value-0'))).data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('value-2'))).data,
      '1',
    );
  });

  testWidgets('보드 셀에 행·열·상태 접근성 설명을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester);

    final emptyCell = tester.getSemantics(
      find.byKey(const ValueKey('semantics-cell-0')),
    );
    final givenCell = tester.getSemantics(
      find.byKey(const ValueKey('semantics-cell-1')),
    );
    expect(emptyCell.label, contains('1행 1열, 빈칸'));
    expect(givenCell.label, contains('1행 2열, 주어진 숫자 5'));
    semantics.dispose();
  });
}
