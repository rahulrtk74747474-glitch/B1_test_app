import 'dart:convert';

import 'package:krutidevtounicode/krutidevtounicode.dart';

enum PracticeMode {
  dailyReview,
  topicPractice,
  wrongAnswers,
  bookmarked,
  mockExam,
  random50,
  revisionAll,
  revisionAgain,
  revisionHard,
  revisionGood,
}

enum ReviewRating { again, hard, good, easy }

enum QuestionLanguage { hindi, english, both }

class Question {
  const Question({
    required this.id,
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.questionEnglish = '',
    this.optionsEnglish = const {},
    this.explanationEnglish = '',
    required this.difficulty,
    required this.source,
    this.image,
    this.images = const [],
    this.optionImages = const {},
  });

  final int id;
  final String topic;
  final String question;
  final Map<String, String> options;
  final String answer;
  final String explanation;
  final String questionEnglish;
  final Map<String, String> optionsEnglish;
  final String explanationEnglish;
  final String difficulty;
  final String source;
  final String? image;
  final List<String> images;
  final Map<String, String> optionImages;

  List<String> get imagePaths {
    if (images.isNotEmpty) return images;
    if (image != null && image!.trim().isNotEmpty) return [image!];
    return const [];
  }

  static String _decodeSegments(dynamic raw, dynamic segments) {
    if (segments is! List) return raw?.toString().trim() ?? '';
    final buffer = StringBuffer();
    for (final item in segments) {
      if (item is! Map) continue;
      final part = Map<String, dynamic>.from(item);
      final text = part['text']?.toString() ?? '';
      buffer.write(
        part['legacy'] == true
            ? KrutidevToUnicode.convertToUnicode(text)
            : text,
      );
    }
    return buffer.toString().replaceAll(RegExp(r'\\s+'), ' ').trim();
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = Map<String, dynamic>.from(json['options'] as Map);
    final legacy = json['legacy_segments'] is Map
        ? Map<String, dynamic>.from(json['legacy_segments'] as Map)
        : const <String, dynamic>{};
    final legacyOptions = legacy['options'] is Map
        ? Map<String, dynamic>.from(legacy['options'] as Map)
        : const <String, dynamic>{};

    final options = <String, String>{};
    for (final key in const ['A', 'B', 'C', 'D']) {
      final value = rawOptions[key];
      if (value == null) {
        throw FormatException('Question ${json['id']} is missing option $key');
      }
      options[key] = _decodeSegments(value, legacyOptions[key]);
    }

    final rawOptionsEnglish = json['options_en'] is Map
        ? Map<String, dynamic>.from(json['options_en'] as Map)
        : const <String, dynamic>{};
    final optionsEnglish = <String, String>{
      for (final key in const ['A', 'B', 'C', 'D'])
        key: rawOptionsEnglish[key]?.toString().trim() ?? '',
    };

    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final legacyImage = json['image']?.toString().trim();
    if (images.isEmpty && legacyImage != null && legacyImage.isNotEmpty) {
      images.add(legacyImage);
    }

    final rawOptionImages = json['option_images'] is Map
        ? Map<String, dynamic>.from(json['option_images'] as Map)
        : const <String, dynamic>{};
    final optionImages = <String, String>{};
    for (final key in const ['A', 'B', 'C', 'D']) {
      final value = rawOptionImages[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) optionImages[key] = value;
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
      question: _decodeSegments(json['question'], legacy['question']),
      options: options,
      answer: answer,
      explanation: (json['explanation_hi'] ?? json['explanation'])?.toString().trim() ?? '',
      questionEnglish: json['question_en']?.toString().trim() ?? '',
      optionsEnglish: optionsEnglish,
      explanationEnglish: json['explanation_en']?.toString().trim() ?? '',
      difficulty: json['difficulty']?.toString().trim() ?? 'medium',
      source: json['source']?.toString().trim() ?? '',
      image: images.isEmpty ? null : images.first,
      images: images,
      optionImages: optionImages,
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
        questionEnglish: (row['question_en'] as String?) ?? '',
        optionsEnglish: {
          'A': (row['option_a_en'] as String?) ?? '',
          'B': (row['option_b_en'] as String?) ?? '',
          'C': (row['option_c_en'] as String?) ?? '',
          'D': (row['option_d_en'] as String?) ?? '',
        },
        explanationEnglish: (row['explanation_en'] as String?) ?? '',
        difficulty: (row['difficulty'] as String?) ?? 'medium',
        source: (row['source'] as String?) ?? '',
        image: row['image_path'] as String?,
        images: _decodeStringList(row['images_json'], fallback: row['image_path'] as String?),
        optionImages: _decodeStringMap(row['option_images_json']),
      );

  static List<String> _decodeStringList(Object? raw, {String? fallback}) {
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    if (fallback != null && fallback.trim().isNotEmpty) return [fallback];
    return const [];
  }

  static Map<String, String> _decodeStringMap(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return {
            for (final entry in decoded.entries)
              if (entry.value?.toString().trim().isNotEmpty == true)
                entry.key.toString(): entry.value.toString(),
          };
        }
      } catch (_) {}
    }
    return const {};
  }

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
        'question_en': questionEnglish,
        'option_a_en': optionsEnglish['A'] ?? '',
        'option_b_en': optionsEnglish['B'] ?? '',
        'option_c_en': optionsEnglish['C'] ?? '',
        'option_d_en': optionsEnglish['D'] ?? '',
        'explanation_en': explanationEnglish,
        'difficulty': difficulty,
        'source': source,
        'image_path': imagePaths.isEmpty ? null : imagePaths.first,
        'images_json': jsonEncode(imagePaths),
        'option_images_json': jsonEncode(optionImages),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'question': question,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        'question_en': questionEnglish,
        'options_en': optionsEnglish,
        'explanation_en': explanationEnglish,
        'difficulty': difficulty,
        'source': source,
        if (imagePaths.isNotEmpty) 'images': imagePaths,
        if (imagePaths.length == 1) 'image': imagePaths.first,
        if (optionImages.isNotEmpty) 'option_images': optionImages,
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
