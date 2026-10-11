import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:b1_test_app/balanced_exam.dart';

void main() {
  test('equal allocation with exact requested size', () {
    final distribution = allocateBalancedQuestions(
      {'BNS': 100, 'BNSS': 100, 'BSA': 100}, 100, random: Random(1));
    expect(distribution.values.fold<int>(0, (a, b) => a + b), 100);
    expect(distribution.values.reduce((a, b) => a > b ? a : b) -
      distribution.values.reduce((a, b) => a < b ? a : b), 1);
  });

  test('redistribute when one subject runs out', () {
    final distribution = allocateBalancedQuestions(
      {'small': 2, 'large': 40, 'other': 40}, 30, random: Random(3));
    expect(distribution['small'], 2);
    expect(distribution.values.fold<int>(0, (a, b) => a + b), 30);
    expect((distribution['large']! - distribution['other']!).abs(), lessThanOrEqualTo(1));
  });

  test('never return more questions than exist', () {
    expect(() => allocateBalancedQuestions({'BNS': 2, 'BSA': 1}, 4),
      throwsArgumentError);
  });

  test('single question still returns exactly one', () {
    final result = allocateBalancedQuestions({'A': 10, 'B': 10}, 1, random: Random(5));
    expect(result.values.single, 1);
  });
}
