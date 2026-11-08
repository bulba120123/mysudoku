import 'package:flutter/material.dart';

import 'data/appearance_store.dart';
import 'screens/home_page.dart';

export 'screens/game_page.dart';
export 'screens/home_page.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatefulWidget {
  const SudokuApp({super.key});

  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  final appearanceStore = AppearanceStore();
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    appearanceStore.loadDarkMode().then((enabled) {
      if (mounted) setState(() => darkMode = enabled);
    });
  }

  void toggleTheme() {
    setState(() => darkMode = !darkMode);
    appearanceStore.saveDarkMode(darkMode);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '나의 스도쿠',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff17324d)),
      scaffoldBackgroundColor: const Color(0xfff7f5ef),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff73b7dc),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff111820),
    ),
    themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    home: HomePage(darkMode: darkMode, onToggleTheme: toggleTheme),
  );
}
