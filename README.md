# B1 Daily Drill

Offline-first Android MCQ exam-practice app built with Flutter + SQLite. It follows a daily-drill / spaced-repetition workflow and is designed for a 6,500+ question bank.

## Implemented

- Five-tab navigation: Home, Practice, Stats, Library, Settings.
- System / Light / Dark themes with minimal rounded-card styling.
- SQLite question bank, progress table and append-only review history.
- SM-2-style scheduling: wrong/Again cards return after 10 minutes; correct answers receive growing intervals.
- Daily Review with due cards plus a configurable new-card limit (default 30).
- Topic Practice, Wrong-Answers Only, Bookmarked, timed Mock Exam with optional -0.25 marking, and Random 50.
- Immediate correct/wrong feedback, explanations, Again / Hard / Good / Easy ratings, bookmarks and personal notes.
- 12-week activity heatmap, 14-day retention chart, 24 badges, topic accuracy, weak topics, average response time and a simple predicted-score estimate.
- Library search by question number/text with wrong, bookmarked, unseen and mastered filters.
- Bulk import of multiple JSON files. Existing IDs are skipped, so files can be merged without duplicate questions.
- Progress export and reset.
- Ten BNS sample questions derived from the supplied 1-6500 PDF.

## Flutter setup

Install a current Flutter stable SDK and Android Studio / Android SDK.

After cloning:

    flutter create --platforms=android --project-name b1_test_app .
    flutter pub get
    flutter test
    flutter run

Generated Android boilerplate is intentionally not committed. GitHub Actions creates it for CI and builds a debug APK automatically.

## Question JSON format

A JSON file may contain one object or an array of objects:

    {
      "id": 1,
      "topic": "BNS",
      "question": "Question text",
      "options": {"A":"...","B":"...","C":"...","D":"..."},
      "answer": "B",
      "explanation": "Short source-supported reason",
      "difficulty": "easy|medium|hard",
      "source": "PDF name, page"
    }

See assets/sample_bns_10.json.

## SQLite schema

The executable schema is in docs/schema.sql and mirrored in lib/database.dart.

questions:
Static content: question ID, topic, prompt, four options, correct key, explanation, difficulty, source and optional image path.

progress:
Per-question state: attempts, correct count, first/last answered, next due, ease factor, interval, repetitions, bookmark, personal note, average time and last result.

reviews:
Append-only attempt history used for streaks, heatmaps, retention and other statistics.

## PDF question-bank plan

The supplied PDF has 337 pages. Its table data is extractable, but the Hindi text uses a legacy font encoding rather than normal Unicode. The app therefore keeps PDF conversion separate from the mobile runtime:

1. Recover numbered PDF rows and answer-key values.
2. Convert legacy Hindi to Unicode.
3. Preserve the PDF question number as the app ID and the page as the source.
4. Import BNS first.
5. Import BNSS second.
6. Continue with BSA, PPR and the remaining subjects.
7. Do not fabricate missing questions or explanations that are not present in the source.

## Still to wire

- Actual Android 6 PM local-notification scheduling. The preference is already in Settings.
- Optional authenticated cloud-sync adapter. Offline SQLite remains the source of truth.

## CI

.github/workflows/flutter.yml runs flutter analyze, flutter test and flutter build apk --debug. Successful runs upload the APK as the b1-test-app-debug-apk artifact.
