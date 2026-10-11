import 'dart:math';

import 'balanced_exam.dart';
import 'database.dart';
import 'models.dart';

class PoliceExamRecord {
  const PoliceExamRecord({
    required this.id, required this.startedAt, required this.total,
    required this.attempted, required this.correct, required this.wrong,
    required this.score, required this.durationMs,
  });
  final int id, startedAt, total, attempted, correct, wrong, durationMs;
  final double score;
  double get accuracy => attempted == 0 ? 0 : correct * 100 / attempted;
  int get skipped => total - attempted;
  factory PoliceExamRecord.fromDb(Map<String, Object?> row) => PoliceExamRecord(
    id: row['id'] as int,
    startedAt: row['started_at'] as int,
    total: row['total'] as int,
    attempted: row['attempted'] as int,
    correct: row['correct'] as int,
    wrong: row['wrong'] as int,
    score: (row['score'] as num).toDouble(),
    durationMs: row['duration_ms'] as int,
  );
}

class PoliceSubjectResult {
  const PoliceSubjectResult({
    required this.topic, required this.total, required this.correct,
    required this.wrong, required this.attempted, required this.previousAccuracy,
  });
  final String topic;
  final int total, correct, wrong, attempted;
  final double? previousAccuracy;
  double get accuracy => total == 0 ? 0 : correct * 100 / total;
  double? get improvement => previousAccuracy == null ? null : accuracy - previousAccuracy!;
}

class PoliceExamRepository {
  PoliceExamRepository._();
  static final instance = PoliceExamRepository._();

  Future<Map<String, int>> subjectInventory() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT topic, COUNT(*) AS count FROM questions GROUP BY topic ORDER BY topic',
    );
    return {for (final r in rows) r['topic'] as String: (r['count'] as num).toInt()};
  }

  Future<List<Question>> balancedRandomQuestions(int count) async {
    final db = await AppDatabase.instance.database;
    final allocation = allocateBalancedQuestions(await subjectInventory(), count);
    final questions = <Question>[];
    for (final item in allocation.entries) {
      final rows = await db.query('questions',
        where: 'topic = ?', whereArgs: [item.key],
        orderBy: 'RANDOM()', limit: item.value);
      questions.addAll(rows.map(Question.fromDb));
    }
    if (questions.length != count) {
      throw StateError('Requested $count questions but got ${questions.length}');
    }
    questions.shuffle(Random());
    return questions;
  }

  Future<PoliceExamRecord> saveExam({
    required List<Question> questions,
    required Map<int, String> selected,
    required DateTime started,
    required int durationMs,
    required bool negativeMarking,
  }) async {
    if (questions.isEmpty) throw ArgumentError('No questions');
    final db = await AppDatabase.instance.database;
    final attempted = questions.where((q) => selected.containsKey(q.id)).length;
    final correct = questions.where((q) => selected[q.id] == q.answer).length;
    final wrong = attempted - correct;
    final score = correct - (negativeMarking ? wrong * .25 : 0.0);
    final endedAt = DateTime.now().millisecondsSinceEpoch;
    final id = await db.transaction<int>((txn) async {
      final id = await txn.insert('exam_sessions', {
        'started_at': started.millisecondsSinceEpoch,
        'finished_at': endedAt, 'total': questions.length,
        'attempted': attempted, 'correct': correct, 'wrong': wrong,
        'score': score, 'duration_ms': durationMs,
        'negative_marking': negativeMarking ? 1 : 0,
      });
      final batch = txn.batch();
      for (final q in questions) {
        batch.insert('exam_answers', {
          'session_id': id, 'question_id': q.id, 'topic': q.topic,
          'selected_answer': selected[q.id], 'correct_answer': q.answer,
          'correct': selected[q.id] == q.answer ? 1 : 0,
          'attempted': selected.containsKey(q.id) ? 1 : 0,
        });
      }
      await batch.commit(noResult: true);
      return id;
    });
    // Exam answers contribute to the existing spaced repetition and accuracy
    // history, without introducing immediate feedback during the test.
    for (final q in questions) {
      if (!selected.containsKey(q.id)) continue;
      final correctAnswer = selected[q.id] == q.answer;
      await AppDatabase.instance.recordAnswer(
        question: q, selectedAnswer: selected[q.id]!,
        correct: correctAnswer,
        rating: correctAnswer ? ReviewRating.good : ReviewRating.again,
        timeMs: durationMs ~/ (attempted == 0 ? 1 : attempted),
        mode: PracticeMode.mockExam,
      );
    }
    return PoliceExamRecord(
      id: id, startedAt: started.millisecondsSinceEpoch,
      total: questions.length, attempted: attempted, correct: correct,
      wrong: wrong, score: score, durationMs: durationMs,
    );
  }

  Future<List<PoliceExamRecord>> history({int limit = 100}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('exam_sessions',
      orderBy: 'finished_at DESC, id DESC', limit: limit);
    return rows.map(PoliceExamRecord.fromDb).toList();
  }

  Future<PoliceExamRecord?> exam(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('exam_sessions',
      where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : PoliceExamRecord.fromDb(rows.first);
  }

  Future<List<PoliceSubjectResult>> subjectResults(int examId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT topic, COUNT(*) AS total, SUM(correct) AS correct,
      SUM(CASE WHEN attempted = 1 AND correct = 0 THEN 1 ELSE 0 END) AS wrong,
      SUM(attempted) AS attempted
      FROM exam_answers WHERE session_id = ? GROUP BY topic ORDER BY topic
    ''', [examId]);
    final previous = await db.rawQuery('''
      SELECT ea.topic, SUM(ea.correct) AS correct, COUNT(*) AS total
      FROM exam_answers ea JOIN exam_sessions es ON ea.session_id = es.id
      WHERE ea.session_id < ? GROUP BY ea.topic
    ''', [examId]);
    final prior = {
      for (final r in previous)
        r['topic'] as String:
        (r['total'] as num).toInt() == 0 ? 0.0 :
        (r['correct'] as num).toDouble() * 100 / (r['total'] as num).toDouble()
    };
    return rows.map((row) => PoliceSubjectResult(
      topic: row['topic'] as String,
      total: (row['total'] as num).toInt(),
      correct: (row['correct'] as num).toInt(),
      wrong: (row['wrong'] as num).toInt(),
      attempted: (row['attempted'] as num).toInt(),
      previousAccuracy: prior[row['topic'] as String],
    )).toList();
  }

  Future<List<PoliceSubjectResult>> overallSubjectResults() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT topic, COUNT(*) AS total, SUM(correct) AS correct,
      SUM(CASE WHEN attempted = 1 AND correct = 0 THEN 1 ELSE 0 END) AS wrong,
      SUM(attempted) AS attempted
      FROM exam_answers GROUP BY topic ORDER BY topic
    ''');
    return rows.map((row) => PoliceSubjectResult(
      topic: row['topic'] as String,
      total: (row['total'] as num).toInt(),
      correct: (row['correct'] as num).toInt(),
      wrong: (row['wrong'] as num).toInt(),
      attempted: (row['attempted'] as num).toInt(),
      previousAccuracy: null,
    )).toList();
  }

  Future<List<Map<String, Object?>>> answersForExam(int examId) async {
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT ea.*, q.question, q.option_a, q.option_b, q.option_c, q.option_d
      FROM exam_answers ea
      LEFT JOIN questions q ON q.id = ea.question_id
      WHERE ea.session_id = ? ORDER BY ea.id
    ''', [examId]);
  }
}
