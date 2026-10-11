import 'package:flutter_test/flutter_test.dart';
import 'package:b1_test_app/models.dart';

void main() {
  test('subject coverage is not mistaken for accuracy', () {
    const t = TopicSummary(topic: 'Police Station Work',
      total: 1537, studied: 1, attempted: 1, correct: 1);
    expect(t.mastery, 100); // 1/1 correctly answered
    expect(t.coverage, closeTo(0.065, 0.001)); // only 1 of 1537 studied
  });

  test('coverage uses distinct studied questions, not repeated attempts', () {
    const t = TopicSummary(topic: 'BNS',
      total: 100, studied: 2, attempted: 10, correct: 8);
    expect(t.coverage, 2);
    expect(t.mastery, 80);
  });

  test('fresh subject always displays zero progress', () {
    const t = TopicSummary(topic: 'BNSS',
      total: 600, studied: 0, attempted: 0, correct: 0);
    expect(t.coverage, 0);
    expect(t.mastery, 0);
  });
}
