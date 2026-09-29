import 'package:b1_test_app/models.dart';
import 'package:b1_test_app/srs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wrong answer returns in ten minutes', () {
    final now = DateTime(2026, 9, 30, 12);
    final result = scheduleReview(
      now: now,
      correct: false,
      rating: ReviewRating.again,
      currentEase: 2.5,
      currentIntervalDays: 6,
      currentRepetitions: 2,
    );
    expect(result.repetitions, 0);
    expect(result.nextDue, now.add(const Duration(minutes: 10)));
  });

  test('good answer grows interval', () {
    final now = DateTime(2026, 9, 30, 12);
    final result = scheduleReview(
      now: now,
      correct: true,
      rating: ReviewRating.good,
      currentEase: 2.5,
      currentIntervalDays: 6,
      currentRepetitions: 2,
    );
    expect(result.repetitions, 3);
    expect(result.intervalDays, 15);
  });
}
