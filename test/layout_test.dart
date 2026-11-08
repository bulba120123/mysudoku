import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/puzzle_repository.dart';
import 'package:sudoku/game/sudoku_logic.dart';
import 'package:sudoku/main.dart';

const _puzzleText =
    '050703060007000800000816000000030000005000100730040086906000204840572093000409000';

SudokuPuzzle _puzzle() => SudokuPuzzle(
  id: 'layout-test',
  difficulty: PuzzleDifficulty.easy,
  rating: 1.2,
  puzzle: _puzzleText,
  solution: SudokuLogic.solve(
    _puzzleText.split('').map(int.parse).toList(),
  ).join(),
);

Widget _app({required Widget home, required bool dark, double textScale = 1}) =>
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );

void main() {
  const sizes = <String, Size>{
    'small iPhone': Size(375, 667),
    'regular iPhone': Size(393, 852),
    'Pro Max': Size(430, 932),
    'iPad': Size(768, 1024),
    'Windows': Size(1280, 800),
  };

  for (final entry in sizes.entries) {
    for (final dark in [false, true]) {
      testWidgets('${entry.key} ${dark ? '다크' : '라이트'} 화면에 오버플로가 없다', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = entry.value;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _app(home: const HomePage(enablePersistence: false), dark: dark),
        );
        expect(find.text('나의 스도쿠'), findsOneWidget);

        await tester.pumpWidget(
          _app(
            home: GamePage(puzzle: _puzzle()),
            dark: dark,
          ),
        );
        expect(find.byKey(const ValueKey('cell-0')), findsOneWidget);

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        expect(find.text('게임 설정'), findsOneWidget);
      });
    }
  }

  testWidgets('작은 iPhone에서 큰 글자 설정을 적용해도 조작할 수 있다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(home: GamePage(puzzle: _puzzle()), dark: false, textScale: 1.4),
    );
    expect(find.byKey(const ValueKey('cell-0')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('number-key-1')));
    expect(find.byKey(const ValueKey('number-key-1')), findsOneWidget);
  });
}
