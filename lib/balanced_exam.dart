import 'dart:math';

/// Allocate an exact total across subjects as evenly as their inventories allow.
/// No subject can be allocated more questions than it owns.
Map<String, int> allocateBalancedQuestions(
  Map<String, int> available,
  int requested, {
  Random? random,
}) {
  final capacity = available.entries.where((e) => e.value > 0).toList();
  final total = capacity.fold<int>(0, (sum, e) => sum + e.value);
  if (requested < 1 || requested > total) {
    throw ArgumentError.value(requested, 'requested', 'Must be 1..$total');
  }
  final rng = random ?? Random();
  capacity.shuffle(rng);
  final selected = {for (final e in capacity) e.key: 0};
  var remaining = requested;
  // Water-fill every subject one question at a time, redistributing shortages.
  while (remaining > 0) {
    var added = false;
    capacity.sort((a, b) => selected[a.key]!.compareTo(selected[b.key]!));
    for (final subject in capacity) {
      if (remaining == 0) break;
      if (selected[subject.key]! >= subject.value) continue;
      selected[subject.key] = selected[subject.key]! + 1;
      remaining--;
      added = true;
    }
    if (!added) throw StateError('Unable to allocate $requested questions');
  }
  return Map.fromEntries(
    selected.entries.where((e) => e.value > 0),
  );
}
