enum PracticeMode {
  dailyReview,
  topicPractice,
  wrongAnswers,
  bookmarked,
  mockExam,
  random50,
}

enum ReviewRating { again, hard, good, easy }

class Question {
  const Question({
    required this.id,
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    required this.source,
    this.image,
  });

  final int id;
  final String topic;
  final String question;
  final Map<String, String> options;
  final String answer;
  final String explanation;
  final String difficulty;
  final String source;
  final String? image;

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = Map<String, dynamic>.from(json['options'] as Map);
    final options = <String, String>{};
    for (final key in const ['A', 'B', 'C', 'D']) {
      final value = rawOptions[key];
      if (value == null) {
        throw FormatException('Question ${json['id']} is missing option $key');
      }
      options[key] = value.toString().trim();
    }
    final answer = json['answer'].toString().toUpperCase().trim();
    if (!options.containsKey(answer)) {
      throw FormatException('Question ${json['id']} has invalid answer: $answer');
    }
    return Question(
      id: int.parse(json['id'].toString()),
      topic: json['topic']?.toString().trim().isNotEmpty == true
          ? json['topic'].toString().trim()
          : 'General',
      question: json['question'].toString().trim(),
      options: options,
      answer: answer,
      explanation: json['explanation']?.toString().trim() ?? '',
      difficulty: json['difficulty']?.toString().trim() ?? 'medium',
      source: json['source']?.toString().trim() ?? '',
      image: json['image']?.toString(),
    );
  }

  factory Question.fromDb(Map<String, Object?> row) => Question(
        id: row['id'] as int,
        topic: row['topic'] as String,
        question: row['question'] as String,
        options: {
          'A': row['option_a'] as String,
          'B': row['option_b'] as String,
          'C': row['option_c'] as String,
          'D': row['option_d'] as String,
        },
        answer: row['answer'] as String,
        explanation: (row['explanation'] as String?) ?? '',
        difficulty: (row['difficulty'] as String?) ?? 'medium',
        source: (row['source'] as String?) ?? '',
        image: row['image_path'] as String?,
      );

  Map<String, Object?> toDb() => {
        'id': id,
        'topic': topic,
        'question': question,
        'option_a': options['A']!,
        'option_b': options['B']!,
        'option_c': options['C']!,
        'option_d': options['D']!,
        'answer': answer,
        'explanation': explanation,
        'difficulty': difficulty,
        'source': source,
        'image_path': image,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'question': question,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        'difficulty': difficulty,
        'source': source,
        if (image != null) 'image': image,
      };
}

class ReviewSchedule {
  const ReviewSchedule({
    required this.ease,
    required this.intervalDays,
    required this.repetitions,
    required this.nextDue,
  });

  final double ease;
  final int intervalDays;
  final int repetitions;
  final DateTime nextDue;
}

class TopicSummary {
  const TopicSummary({
    required this.topic,
    required this.total,
    required this.attempted,
    required this.correct,
  });

  final String topic;
  final int total;
  final int attempted;
  final int correct;

  double get mastery => attempted == 0 ? 0 : (correct / attempted * 100).clamp(0, 100).toDouble();
}

class StatsSnapshot {
  const StatsSnapshot({
    required this.totalReviews,
    required this.correctReviews,
    required this.currentStreak,
    required this.averageTimeMs,
    required this.activity,
    required this.retention,
    required this.topics,
  });

  final int totalReviews;
  final int correctReviews;
  final int currentStreak;
  final double averageTimeMs;
  final Map<DateTime, int> activity;
  final Map<DateTime, double> retention;
  final List<TopicSummary> topics;

  double get accuracy => totalReviews == 0 ? 0 : correctReviews / totalReviews * 100;
  double get predictedScore => accuracy.clamp(0, 100).toDouble();
}
