class GameSnapshot {
  GameSnapshot(this.values, this.notes, this.eliminated);

  final List<int> values;
  final List<Set<int>> notes;
  final List<Set<int>> eliminated;

  GameSnapshot copy() => GameSnapshot(
    List<int>.from(values),
    notes.map(Set<int>.from).toList(),
    eliminated.map(Set<int>.from).toList(),
  );
}
