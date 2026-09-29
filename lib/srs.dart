import 'dart:math' as math;

import 'models.dart';

ReviewSchedule scheduleReview({
  required DateTime now,
  required bool correct,
  required ReviewRating rating,
  required double currentEase,
  required int currentIntervalDays,
  required int currentRepetitions,
}) {
  var ease = currentEase <= 0 ? 2.5 : currentEase;
  var interval = currentIntervalDays;
  var repetitions = currentRepetitions;

  if (!correct || rating == ReviewRating.again) {
    ease = math.max(1.3, ease - 0.2);
    return ReviewSchedule(
      ease: ease,
      intervalDays: 0,
      repetitions: 0,
      nextDue: now.add(const Duration(minutes: 10)),
    );
  }

  repetitions += 1;
  switch (rating) {
    case ReviewRating.again:
      break;
    case ReviewRating.hard:
      ease = math.max(1.3, ease - 0.15);
      interval = repetitions == 1
          ? 1
          : math.max(1, (math.max(1, interval) * 1.2).round());
      break;
    case ReviewRating.good:
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = math.max(1, (math.max(1, interval) * ease).round());
      }
      break;
    case ReviewRating.easy:
      ease = math.min(3.2, ease + 0.15);
      if (repetitions == 1) {
        interval = 4;
      } else {
        interval = math.max(2, (math.max(1, interval) * ease * 1.3).round());
      }
      break;
  }

  return ReviewSchedule(
    ease: ease,
    intervalDays: interval,
    repetitions: repetitions,
    nextDue: now.add(Duration(days: interval)),
  );
}
