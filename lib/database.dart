import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'srs.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'b1_daily_drill.db');
    return openDatabase(
      path,
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY,
            topic TEXT NOT NULL,
            question TEXT NOT NULL,
            option_a TEXT NOT NULL,
            option_b TEXT NOT NULL,
            option_c TEXT NOT NULL,
            option_d TEXT NOT NULL,
            answer TEXT NOT NULL CHECK(answer IN ('A','B','C','D')),
            explanation TEXT NOT NULL DEFAULT '',
            question_en TEXT NOT NULL DEFAULT '',
            option_a_en TEXT NOT NULL DEFAULT '',
            option_b_en TEXT NOT NULL DEFAULT '',
            option_c_en TEXT NOT NULL DEFAULT '',
            option_d_en TEXT NOT NULL DEFAULT '',
            explanation_en TEXT NOT NULL DEFAULT '',
            difficulty TEXT NOT NULL DEFAULT 'medium',
            source TEXT NOT NULL DEFAULT '',
            image_path TEXT,
            images_json TEXT NOT NULL DEFAULT '[]',
            option_images_json TEXT NOT NULL DEFAULT '{}',
            imported_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_questions_topic ON questions(topic)');
        await db.execute('''
          CREATE TABLE progress (
            question_id INTEGER PRIMARY KEY,
            attempts INTEGER NOT NULL DEFAULT 0,
            correct_count INTEGER NOT NULL DEFAULT 0,
            last_answered INTEGER,
            first_answered INTEGER,
            next_due INTEGER NOT NULL DEFAULT 0,
            ease_factor REAL NOT NULL DEFAULT 2.5,
            interval_days INTEGER NOT NULL DEFAULT 0,
            repetitions INTEGER NOT NULL DEFAULT 0,
            bookmarked INTEGER NOT NULL DEFAULT 0,
            personal_note TEXT NOT NULL DEFAULT '',
            average_time_ms REAL NOT NULL DEFAULT 0,
            last_result INTEGER,
            last_rating TEXT,
            repeat_every INTEGER NOT NULL DEFAULT 0,
            next_repeat_review INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_progress_due ON progress(next_due)');
        await db.execute('''
          CREATE TABLE reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id INTEGER NOT NULL,
            answered_at INTEGER NOT NULL,
            correct INTEGER NOT NULL,
            rating TEXT NOT NULL,
            time_ms INTEGER NOT NULL,
            selected_answer TEXT NOT NULL,
            mode TEXT NOT NULL,
            FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_reviews_answered ON reviews(answered_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE questions ADD COLUMN question_en TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE questions ADD COLUMN option_a_en TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE questions ADD COLUMN option_b_en TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE questions ADD COLUMN option_c_en TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE questions ADD COLUMN option_d_en TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE questions ADD COLUMN explanation_en TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE progress ADD COLUMN last_rating TEXT");
          await db.execute("ALTER TABLE progress ADD COLUMN repeat_every INTEGER NOT NULL DEFAULT 0");
          await db.execute("ALTER TABLE progress ADD COLUMN next_repeat_review INTEGER NOT NULL DEFAULT 0");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE questions ADD COLUMN images_json TEXT NOT NULL DEFAULT '[]'");
          await db.execute("ALTER TABLE questions ADD COLUMN option_images_json TEXT NOT NULL DEFAULT '{}'");
        }
      },
    );
  }

  Future<void> seedSampleIfEmpty() async {
    final db = await database;
    final text = await rootBundle.loadString('assets/sample_bns_10.json');
    final decoded = jsonDecode(text) as List<dynamic>;
    final questions = decoded
        .map((item) => Question.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    await db.transaction((txn) async {
      for (final question in questions) {
        final existing = await txn.query(
          'questions',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [question.id],
          limit: 1,
        );
        final values = {
          ...question.toDb(),
          'imported_at': DateTime.now().millisecondsSinceEpoch,
        };
        if (existing.isEmpty) {
          await txn.insert('questions', values);
        } else {
          values.remove('id');
          await txn.update(
            'questions',
            values,
            where: 'id = ?',
            whereArgs: [question.id],
          );
        }
      }
    });
  }

  Future<Directory> _questionMediaDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'question_media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _normalizeArchivePath(String value) {
    var normalized = value.replaceAll('\\', '/').trim();
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();
    if (parts.any((part) => part == '..')) {
      throw const FormatException('Image path cannot contain ..');
    }
    return parts.join('/');
  }

  String _extensionForMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('png')) return '.png';
    if (lower.contains('webp')) return '.webp';
    if (lower.contains('gif')) return '.gif';
    if (lower.contains('bmp')) return '.bmp';
    return '.jpg';
  }

  Future<String> _saveImageBytes(
    Uint8List bytes, {
    required int questionId,
    required String label,
    String? preferredName,
    String? mime,
  }) async {
    final dir = await _questionMediaDirectory();
    final preferredExt = preferredName == null ? '' : p.extension(preferredName);
    final ext = preferredExt.isNotEmpty ? preferredExt : _extensionForMime(mime ?? '');
    final safeLabel = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      p.join(
        dir.path,
        'q${questionId}_${safeLabel}_${DateTime.now().microsecondsSinceEpoch}$ext',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> _materializeImageValue(
    dynamic raw, {
    required int questionId,
    required String label,
    Map<String, Uint8List> archiveFiles = const {},
  }) async {
    if (raw == null) return null;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'] ?? map['base64'];
      if (data != null) {
        var encoded = data.toString().trim();
        var mime = map['mime']?.toString() ?? map['type']?.toString() ?? '';
        if (encoded.startsWith('data:')) {
          final comma = encoded.indexOf(',');
          if (comma < 0) throw const FormatException('Invalid embedded image data URI');
          final header = encoded.substring(5, comma);
          mime = header.split(';').first;
          encoded = encoded.substring(comma + 1);
        }
        final bytes = base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));
        return _saveImageBytes(
          Uint8List.fromList(bytes),
          questionId: questionId,
          label: label,
          preferredName: map['name']?.toString(),
          mime: mime,
        );
      }
      final pathValue = map['path'] ?? map['file'];
      if (pathValue != null) {
        return _materializeImageValue(
          pathValue.toString(),
          questionId: questionId,
          label: label,
          archiveFiles: archiveFiles,
        );
      }
      return null;
    }

    final value = raw.toString().trim();
    if (value.isEmpty) return null;

    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma < 0) throw const FormatException('Invalid embedded image data URI');
      final header = value.substring(5, comma);
      final mime = header.split(';').first;
      final encoded = value.substring(comma + 1).replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(encoded);
      return _saveImageBytes(
        Uint8List.fromList(bytes),
        questionId: questionId,
        label: label,
        mime: mime,
      );
    }

    final normalized = _normalizeArchivePath(value);
    final archived = archiveFiles[normalized] ??
        archiveFiles['images/$normalized'] ??
        archiveFiles[p.basename(normalized)];
    if (archived != null) {
      return _saveImageBytes(
        archived,
        questionId: questionId,
        label: label,
        preferredName: normalized,
      );
    }

    return value;
  }

  Future<Map<String, dynamic>> _prepareQuestionJson(
    Map<String, dynamic> source, {
    Map<String, Uint8List> archiveFiles = const {},
  }) async {
    final json = Map<String, dynamic>.from(source);
    final questionId = int.parse(json['id'].toString());

    dynamic rawImages = json['images'];
    if (rawImages == null && json['image'] != null) rawImages = [json['image']];
    if (rawImages == null && json['image_base64'] != null) {
      rawImages = [
        {
          'base64': json['image_base64'],
          'mime': json['image_mime'] ?? 'image/jpeg',
          'name': json['image_name'],
        }
      ];
    }

    final preparedImages = <String>[];
    if (rawImages is List) {
      for (var i = 0; i < rawImages.length; i++) {
        final path = await _materializeImageValue(
          rawImages[i],
          questionId: questionId,
          label: 'question_${i + 1}',
          archiveFiles: archiveFiles,
        );
        if (path != null && path.isNotEmpty) preparedImages.add(path);
      }
    } else if (rawImages != null) {
      final path = await _materializeImageValue(
        rawImages,
        questionId: questionId,
        label: 'question_1',
        archiveFiles: archiveFiles,
      );
      if (path != null && path.isNotEmpty) preparedImages.add(path);
    }

    final preparedOptionImages = <String, String>{};
    final rawOptionImages = json['option_images'];
    if (rawOptionImages is Map) {
      for (final key in const ['A', 'B', 'C', 'D']) {
        final path = await _materializeImageValue(
          rawOptionImages[key],
          questionId: questionId,
          label: 'option_$key',
          archiveFiles: archiveFiles,
        );
        if (path != null && path.isNotEmpty) preparedOptionImages[key] = path;
      }
    }

    final rawOptionBase64 = json['option_images_base64'];
    if (rawOptionBase64 is Map) {
      for (final key in const ['A', 'B', 'C', 'D']) {
        if (preparedOptionImages.containsKey(key) || rawOptionBase64[key] == null) continue;
        final path = await _materializeImageValue(
          {
            'base64': rawOptionBase64[key],
            'mime': 'image/jpeg',
            'name': 'option_$key.jpg',
          },
          questionId: questionId,
          label: 'option_$key',
          archiveFiles: archiveFiles,
        );
        if (path != null && path.isNotEmpty) preparedOptionImages[key] = path;
      }
    }

    if (preparedImages.isNotEmpty) {
      json['images'] = preparedImages;
      json['image'] = preparedImages.first;
    } else {
      json.remove('images');
      json.remove('image');
    }
    json['option_images'] = preparedOptionImages;
    json.remove('image_base64');
    json.remove('image_mime');
    json.remove('image_name');
    json.remove('option_images_base64');
    return json;
  }

  Future<({int inserted, int skipped, int images})> _importRows(
    List<dynamic> rows, {
    Map<String, Uint8List> archiveFiles = const {},
  }) async {
    final questions = <Question>[];
    var imageCount = 0;
    for (final item in rows) {
      if (item is! Map) throw const FormatException('Every question must be a JSON object');
      final prepared = await _prepareQuestionJson(
        Map<String, dynamic>.from(item),
        archiveFiles: archiveFiles,
      );
      final question = Question.fromJson(prepared);
      questions.add(question);
      imageCount += question.imagePaths.length + question.optionImages.length;
    }

    final db = await database;
    var inserted = 0;
    var skipped = 0;
    await db.transaction((txn) async {
      for (final question in questions) {
        final result = await txn.insert(
          'questions',
          {...question.toDb(), 'imported_at': DateTime.now().millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        result > 0 ? inserted++ : skipped++;
      }
    });
    return (inserted: inserted, skipped: skipped, images: imageCount);
  }

  Future<({int inserted, int skipped, int images})> importJsonText(String text) async {
    final decoded = jsonDecode(text);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['questions'] is List
            ? decoded['questions'] as List
            : [decoded];
    return _importRows(rows);
  }

  Future<({int inserted, int skipped, int images})> importQuestionBankBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final extension = p.extension(fileName).toLowerCase();
    if (extension == '.json') {
      return importJsonText(utf8.decode(bytes));
    }
    if (extension != '.zip') {
      throw const FormatException('Choose a .json or .zip question bank');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final archiveFiles = <String, Uint8List>{};
    String? jsonText;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = _normalizeArchivePath(entry.name);
      final content = entry.readBytes();
      if (content == null) continue;
      if (p.basename(name).toLowerCase() == 'questions.json') {
        jsonText = utf8.decode(content);
      } else {
        final ext = p.extension(name).toLowerCase();
        if (const ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'].contains(ext)) {
          archiveFiles[name] = content;
          archiveFiles[p.basename(name)] = content;
        }
      }
    }

    if (jsonText == null) {
      throw const FormatException('ZIP must contain questions.json');
    }

    final decoded = jsonDecode(jsonText);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['questions'] is List
            ? decoded['questions'] as List
            : [decoded];
    return _importRows(rows, archiveFiles: archiveFiles);
  }

  Future<int> questionCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM questions')) ?? 0;
  }

  Future<int> totalReviewCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reviews')) ?? 0;
  }

  Future<int> dueCount() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final reviewCount = await totalReviewCount();
    return Sqflite.firstIntValue(await db.rawQuery(
          '''
          SELECT COUNT(*) FROM progress
          WHERE attempts > 0
            AND (
              (last_rating IN ('again','hard','good') AND next_repeat_review > 0 AND next_repeat_review <= ?)
              OR
              ((last_rating IS NULL OR last_rating = 'easy') AND next_due <= ?)
            )
          ''',
          [reviewCount, now],
        )) ??
        0;
  }

  Future<Map<String, int>> revisionCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT last_rating, COUNT(*) AS total
      FROM progress
      WHERE last_rating IN ('again','hard','good')
      GROUP BY last_rating
    ''');
    final result = {'again': 0, 'hard': 0, 'good': 0};
    for (final row in rows) {
      final key = row['last_rating'] as String?;
      if (key != null && result.containsKey(key)) {
        result[key] = (row['total'] as num).toInt();
      }
    }
    return result;
  }

  Future<List<Question>> dueRevisionQuestions({int limit = 5}) async {
    final db = await database;
    final reviewCount = await totalReviewCount();
    final rows = await db.rawQuery('''
      SELECT q.* FROM questions q
      JOIN progress p ON p.question_id = q.id
      WHERE p.last_rating IN ('again','hard','good')
        AND p.next_repeat_review > 0
        AND p.next_repeat_review <= ?
      ORDER BY
        p.next_repeat_review ASC,
        CASE p.last_rating WHEN 'again' THEN 1 WHEN 'hard' THEN 2 ELSE 3 END,
        p.last_answered ASC
      LIMIT ?
    ''', [reviewCount, limit]);
    return rows.map(Question.fromDb).toList();
  }

  Future<List<Question>> revisionQuestions(String rating, {int limit = 200}) async {
    final db = await database;
    final clause = rating == 'all'
        ? "p.last_rating IN ('again','hard','good')"
        : 'p.last_rating = ?';
    final args = <Object?>[];
    if (rating != 'all') args.add(rating);
    args.add(limit);
    final rows = await db.rawQuery('''
      SELECT q.* FROM questions q
      JOIN progress p ON p.question_id = q.id
      WHERE $clause
      ORDER BY
        CASE p.last_rating WHEN 'again' THEN 1 WHEN 'hard' THEN 2 ELSE 3 END,
        p.last_answered DESC
      LIMIT ?
    ''', args);
    return rows.map(Question.fromDb).toList();
  }

  Future<List<TopicSummary>> topicSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT q.topic,
             COUNT(q.id) AS total,
             COALESCE(SUM(CASE WHEN p.attempts > 0 THEN 1 ELSE 0 END), 0) AS attempted,
             COALESCE(SUM(p.correct_count), 0) AS correct,
             COALESCE(SUM(p.attempts), 0) AS attempts_total
      FROM questions q
      LEFT JOIN progress p ON p.question_id = q.id
      GROUP BY q.topic
      ORDER BY q.topic COLLATE NOCASE
    ''');
    return rows.map((row) {
      final attemptsTotal = (row['attempts_total'] as num).toInt();
      return TopicSummary(
        topic: row['topic'] as String,
        total: (row['total'] as num).toInt(),
        attempted: attemptsTotal == 0 ? 0 : attemptsTotal,
        correct: (row['correct'] as num).toInt(),
      );
    }).toList();
  }

  Future<List<String>> topics() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT topic FROM questions ORDER BY topic COLLATE NOCASE');
    return rows.map((row) => row['topic'] as String).toList();
  }

  Future<int> topicQuestionCount(String topic) async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM questions WHERE topic = ?',
            [topic],
          ),
        ) ??
        0;
  }

  Future<List<Question>> buildSession({
    required PracticeMode mode,
    int sessionSize = 15,
    int dailyNewLimit = 30,
    String? topic,
  }) async {
    final db = await database;
    final limit = mode == PracticeMode.random50 ? 50 : math.max(1, sessionSize);
    List<Map<String, Object?>> rows;

    switch (mode) {
      case PracticeMode.dailyReview:
        final now = DateTime.now();
        final reviewCount = await totalReviewCount();
        final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final tomorrow = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
        final introduced = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM progress WHERE first_answered >= ? AND first_answered < ?',
              [start, tomorrow],
            )) ??
            0;
        final newRemaining = math.max(0, dailyNewLimit - introduced);
        final dueRows = await db.rawQuery('''
          SELECT q.* FROM questions q
          JOIN progress p ON p.question_id = q.id
          WHERE p.attempts > 0
            AND (
              (p.last_rating IN ('again','hard','good') AND p.next_repeat_review > 0 AND p.next_repeat_review <= ?)
              OR
              ((p.last_rating IS NULL OR p.last_rating = 'easy') AND p.next_due <= ?)
            )
          ORDER BY
            CASE p.last_rating WHEN 'again' THEN 1 WHEN 'hard' THEN 2 WHEN 'good' THEN 3 ELSE 4 END,
            p.next_repeat_review ASC,
            p.next_due ASC
          LIMIT ?
        ''', [reviewCount, now.millisecondsSinceEpoch, limit]);
        rows = [...dueRows];
        final remainingSlots = math.max(0, limit - rows.length);
        final takeNew = math.min(remainingSlots, newRemaining);
        if (takeNew > 0) {
          final newRows = await db.rawQuery('''
            SELECT q.* FROM questions q
            LEFT JOIN progress p ON p.question_id = q.id
            WHERE p.question_id IS NULL OR p.attempts = 0
            ORDER BY q.id ASC
            LIMIT ?
          ''', [takeNew]);
          rows.addAll(newRows);
        }
        break;
      case PracticeMode.topicPractice:
        rows = await db.rawQuery(
          'SELECT * FROM questions WHERE topic = ? ORDER BY RANDOM() LIMIT ?',
          [topic ?? '', limit],
        );
        break;
      case PracticeMode.wrongAnswers:
        rows = await db.rawQuery('''
          SELECT q.* FROM questions q
          JOIN progress p ON p.question_id = q.id
          WHERE p.last_result = 0
          ORDER BY p.last_answered DESC
          LIMIT ?
        ''', [limit]);
        break;
      case PracticeMode.bookmarked:
        rows = await db.rawQuery('''
          SELECT q.* FROM questions q
          JOIN progress p ON p.question_id = q.id
          WHERE p.bookmarked = 1
          ORDER BY q.id
          LIMIT ?
        ''', [limit]);
        break;
      case PracticeMode.mockExam:
        rows = await db.rawQuery('SELECT * FROM questions ORDER BY RANDOM() LIMIT ?', [limit]);
        break;
      case PracticeMode.random50:
        rows = await db.rawQuery('SELECT * FROM questions ORDER BY RANDOM() LIMIT 50');
        break;
      case PracticeMode.revisionAll:
        rows = (await revisionQuestions('all', limit: limit)).map((q) => q.toDb()).toList();
        break;
      case PracticeMode.revisionAgain:
        rows = (await revisionQuestions('again', limit: limit)).map((q) => q.toDb()).toList();
        break;
      case PracticeMode.revisionHard:
        rows = (await revisionQuestions('hard', limit: limit)).map((q) => q.toDb()).toList();
        break;
      case PracticeMode.revisionGood:
        rows = (await revisionQuestions('good', limit: limit)).map((q) => q.toDb()).toList();
        break;
    }
    return rows.map(Question.fromDb).toList();
  }

  Future<void> recordAnswer({
    required Question question,
    required String selectedAnswer,
    required bool correct,
    required ReviewRating rating,
    required int timeMs,
    required PracticeMode mode,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'progress',
        where: 'question_id = ?',
        whereArgs: [question.id],
        limit: 1,
      );
      final row = existing.isEmpty ? <String, Object?>{} : existing.first;
      final attempts = ((row['attempts'] as int?) ?? 0) + 1;
      final correctCount = ((row['correct_count'] as int?) ?? 0) + (correct ? 1 : 0);
      final oldAverage = ((row['average_time_ms'] as num?) ?? 0).toDouble();
      final newAverage = ((oldAverage * (attempts - 1)) + timeMs) / attempts;
      final schedule = scheduleReview(
        now: now,
        correct: correct,
        rating: rating,
        currentEase: ((row['ease_factor'] as num?) ?? 2.5).toDouble(),
        currentIntervalDays: (row['interval_days'] as int?) ?? 0,
        currentRepetitions: (row['repetitions'] as int?) ?? 0,
      );
      final firstAnswered = (row['first_answered'] as int?) ?? now.millisecondsSinceEpoch;

      final reviewId = await txn.insert('reviews', {
        'question_id': question.id,
        'answered_at': now.millisecondsSinceEpoch,
        'correct': correct ? 1 : 0,
        'rating': rating.name,
        'time_ms': timeMs,
        'selected_answer': selectedAnswer,
        'mode': mode.name,
      });

      final repeatEvery = switch (rating) {
        ReviewRating.again => 10,
        ReviewRating.hard => 30,
        ReviewRating.good => 70,
        ReviewRating.easy => 0,
      };
      final nextRepeatReview = repeatEvery == 0 ? 0 : reviewId + repeatEvery;

      await txn.insert(
        'progress',
        {
          'question_id': question.id,
          'attempts': attempts,
          'correct_count': correctCount,
          'last_answered': now.millisecondsSinceEpoch,
          'first_answered': firstAnswered,
          'next_due': schedule.nextDue.millisecondsSinceEpoch,
          'ease_factor': schedule.ease,
          'interval_days': schedule.intervalDays,
          'repetitions': schedule.repetitions,
          'bookmarked': (row['bookmarked'] as int?) ?? 0,
          'personal_note': (row['personal_note'] as String?) ?? '',
          'average_time_ms': newAverage,
          'last_result': correct ? 1 : 0,
          'last_rating': rating.name,
          'repeat_every': repeatEvery,
          'next_repeat_review': nextRepeatReview,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<bool> isBookmarked(int questionId) async {
    final db = await database;
    final rows = await db.query('progress', columns: ['bookmarked'], where: 'question_id = ?', whereArgs: [questionId]);
    return rows.isNotEmpty && rows.first['bookmarked'] == 1;
  }

  Future<void> toggleBookmark(int questionId) async {
    final db = await database;
    final rows = await db.query('progress', where: 'question_id = ?', whereArgs: [questionId]);
    if (rows.isEmpty) {
      await db.insert('progress', {'question_id': questionId, 'bookmarked': 1, 'next_due': 0});
    } else {
      final current = rows.first['bookmarked'] == 1;
      await db.update('progress', {'bookmarked': current ? 0 : 1}, where: 'question_id = ?', whereArgs: [questionId]);
    }
  }

  Future<String> noteFor(int questionId) async {
    final db = await database;
    final rows = await db.query('progress', columns: ['personal_note'], where: 'question_id = ?', whereArgs: [questionId]);
    return rows.isEmpty ? '' : (rows.first['personal_note'] as String? ?? '');
  }

  Future<void> saveNote(int questionId, String note) async {
    final db = await database;
    final rows = await db.query('progress', where: 'question_id = ?', whereArgs: [questionId]);
    if (rows.isEmpty) {
      await db.insert('progress', {'question_id': questionId, 'personal_note': note, 'next_due': 0});
    } else {
      await db.update('progress', {'personal_note': note}, where: 'question_id = ?', whereArgs: [questionId]);
    }
  }

  Future<List<Question>> librarySearch({
    String query = '',
    String filter = 'all',
    int limit = 200,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      final q = query.trim();
      if (int.tryParse(q) != null) {
        where.add('(CAST(q.id AS TEXT) = ? OR q.question LIKE ?)');
        args.add(q);
        args.add('%$q%');
      } else {
        where.add('(q.question LIKE ? OR q.question_en LIKE ? OR q.topic LIKE ? OR q.source LIKE ?)');
        args.addAll(['%$q%', '%$q%', '%$q%', '%$q%']);
      }
    }
    switch (filter) {
      case 'wrong':
        where.add('p.last_result = 0');
        break;
      case 'bookmarked':
        where.add('p.bookmarked = 1');
        break;
      case 'unseen':
        where.add('(p.question_id IS NULL OR p.attempts = 0)');
        break;
      case 'mastered':
        where.add('(p.attempts >= 3 AND (p.correct_count * 1.0 / p.attempts) >= 0.80)');
        break;
    }
    args.add(limit);
    final rows = await db.rawQuery('''
      SELECT q.* FROM questions q
      LEFT JOIN progress p ON p.question_id = q.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY q.id
      LIMIT ?
    ''', args);
    return rows.map(Question.fromDb).toList();
  }

  Future<StatsSnapshot> stats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reviews')) ?? 0;
    final correct = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reviews WHERE correct = 1')) ?? 0;
    final avgRows = await db.rawQuery('SELECT AVG(time_ms) AS avg_ms FROM reviews');
    final avgMs = ((avgRows.first['avg_ms'] as num?) ?? 0).toDouble();

    final now = DateTime.now();
    final start84 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 83));
    final rows = await db.rawQuery(
      'SELECT answered_at, correct FROM reviews WHERE answered_at >= ? ORDER BY answered_at',
      [start84.millisecondsSinceEpoch],
    );
    final activity = <DateTime, int>{};
    final dayCorrect = <DateTime, int>{};
    for (final row in rows) {
      final dt = DateTime.fromMillisecondsSinceEpoch(row['answered_at'] as int);
      final day = DateTime(dt.year, dt.month, dt.day);
      activity[day] = (activity[day] ?? 0) + 1;
      if (row['correct'] == 1) dayCorrect[day] = (dayCorrect[day] ?? 0) + 1;
    }
    final retention = <DateTime, double>{};
    for (var i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final attempts = activity[day] ?? 0;
      retention[day] = attempts == 0 ? 0 : (dayCorrect[day] ?? 0) / attempts;
    }

    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    if ((activity[cursor] ?? 0) == 0) cursor = cursor.subtract(const Duration(days: 1));
    while ((activity[cursor] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return StatsSnapshot(
      totalReviews: total,
      correctReviews: correct,
      currentStreak: streak,
      averageTimeMs: avgMs,
      activity: activity,
      retention: retention,
      topics: await topicSummaries(),
    );
  }

  Future<String> exportProgress() async {
    final db = await database;
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'progress': await db.query('progress', orderBy: 'question_id'),
      'reviews': await db.query('reviews', orderBy: 'id'),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'b1_progress_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  Future<void> resetProgress() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reviews');
      await txn.delete('progress');
    });
  }
}
