import 'package:flutter/material.dart';

import '../data/game_save_store.dart';
import '../data/played_puzzle_store.dart';
import '../data/puzzle_repository.dart';
import '../ui/puzzle_difficulty_label.dart';
import 'game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    this.enablePersistence = true,
    this.darkMode = false,
    this.onToggleTheme,
    super.key,
  });

  final bool enablePersistence;
  final bool darkMode;
  final VoidCallback? onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repository = PuzzleRepository();
  PlayedPuzzleStore? _playedStore;
  PlayedPuzzleStore get playedStore => _playedStore ??= PlayedPuzzleStore();
  final saveStore = GameSaveStore();
  SavedGame? savedGame;
  PuzzleDifficulty? loadingDifficulty;

  @override
  void initState() {
    super.initState();
    if (widget.enablePersistence) loadSavedGame();
  }

  Future<void> loadSavedGame() async {
    final saved = await saveStore.load();
    if (mounted) setState(() => savedGame = saved);
  }

  Future<void> continueGame() async {
    final saved = savedGame;
    if (saved == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          puzzle: saved.puzzle,
          restoredGame: saved,
          saveStore: saveStore,
          darkMode: widget.darkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
    if (mounted) await loadSavedGame();
  }

  Future<void> start(PuzzleDifficulty difficulty) async {
    if (loadingDifficulty != null) return;
    if (savedGame != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('새 게임을 시작할까요?'),
          content: const Text('현재 진행 중인 게임은 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새 게임'),
            ),
          ],
        ),
      );
      if (replace != true) return;
      await saveStore.clear();
      savedGame = null;
    }
    setState(() => loadingDifficulty = difficulty);
    try {
      var played = await playedStore.ids(difficulty);
      var puzzle = await repository.randomUnplayed(difficulty, played);
      if (puzzle == null) {
        await playedStore.reset(difficulty);
        played = {};
        puzzle = await repository.randomUnplayed(difficulty, played);
      }
      if (puzzle == null) throw StateError('사용 가능한 문제가 없습니다.');
      await playedStore.markPlayed(difficulty, puzzle.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GamePage(
            puzzle: puzzle!,
            saveStore: widget.enablePersistence ? saveStore : null,
            darkMode: widget.darkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
      if (mounted && widget.enablePersistence) await loadSavedGame();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제를 불러오지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => loadingDifficulty = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: widget.darkMode ? '라이트 모드' : '다크 모드',
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      widget.darkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                ),
                const Icon(
                  Icons.grid_3x3_rounded,
                  size: 62,
                  color: Color(0xff17324d),
                ),
                const SizedBox(height: 18),
                const Text(
                  '나의 스도쿠',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  '난이도를 선택하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff6f777e), fontSize: 16),
                ),
                const SizedBox(height: 28),
                if (savedGame != null) ...[
                  SizedBox(
                    height: 64,
                    child: FilledButton.icon(
                      key: const ValueKey('continue-game'),
                      onPressed: continueGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff2f7d67),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        '이어하기 · ${savedGame!.puzzle.difficulty.label}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final difficulty in PuzzleDifficulty.values) ...[
                  difficultyButton(difficulty),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                const Text(
                  '총 10,000문제 · 오프라인',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff8a8f94), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget difficultyButton(PuzzleDifficulty difficulty) {
    final loading = loadingDifficulty == difficulty;
    return SizedBox(
      height: 58,
      child: FilledButton(
        key: ValueKey('difficulty-${difficulty.name}'),
        onPressed: loadingDifficulty == null ? () => start(difficulty) : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff17324d),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                difficulty.label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
