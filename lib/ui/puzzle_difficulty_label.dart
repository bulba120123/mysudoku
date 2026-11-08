import '../data/puzzle_repository.dart';

extension PuzzleDifficultyLabel on PuzzleDifficulty {
  String get label => switch (this) {
    PuzzleDifficulty.beginner => '입문',
    PuzzleDifficulty.easy => '쉬움',
    PuzzleDifficulty.medium => '보통',
    PuzzleDifficulty.hard => '어려움',
    PuzzleDifficulty.expert => '전문가',
    PuzzleDifficulty.master => '마스터',
  };
}
