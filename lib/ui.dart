import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'models.dart';

const green = Color(0xFF22A06B);
const amber = Color(0xFFF59E0B);
const red = Color(0xFFE5484D);

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.prefs,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final SharedPreferences prefs;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  int revision = 0;

  void refresh() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: ValueKey('home-$revision'), prefs: widget.prefs),
      PracticeScreen(key: ValueKey('practice-$revision'), prefs: widget.prefs),
      StatsScreen(key: ValueKey('stats-$revision')),
      LibraryScreen(key: ValueKey('library-$revision')),
      SettingsScreen(
        key: ValueKey('settings-$revision'),
        prefs: widget.prefs,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onDataChanged: refresh,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<({int due, StatsSnapshot stats, List<TopicSummary> topics})> future;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<({int due, StatsSnapshot stats, List<TopicSummary> topics})> _loadData() async => (
        due: await AppDatabase.instance.dueCount(),
        stats: await AppDatabase.instance.stats(),
        topics: await AppDatabase.instance.topicSummaries(),
      );

  void load() {
    future = _loadData();
  }

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> startReview() async {
    final questions = await AppDatabase.instance.buildSession(
      mode: PracticeMode.dailyReview,
      sessionSize: widget.prefs.getInt('session_size') ?? 15,
      dailyNewLimit: widget.prefs.getInt('daily_new_limit') ?? 30,
    );
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing is due right now.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          mode: PracticeMode.dailyReview,
          prefs: widget.prefs,
        ),
      ),
    );
    if (mounted) setState(load);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int due, StatsSnapshot stats, List<TopicSummary> topics})>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(load),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting()),
                        const SizedBox(height: 4),
                        Text(
                          'Ready to drill?',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    icon: Icons.local_fire_department,
                    text: data.stats.currentStreak.toString() + ' day streak',
                    color: amber,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DUE TODAY', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    Text(data.due.toString(), style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900)),
                    const Text('due reviews; new cards are added by your daily limit', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF312E81)),
                      onPressed: startReview,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start review'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Topics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (data.topics.isEmpty)
                const Text('Import a question bank to see topics here.')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.topics.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.18,
                  ),
                  itemBuilder: (context, i) {
                    final topic = data.topics[i];
                    final color = topic.mastery >= 50 ? green : amber;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withValues(alpha: .12),
                                  foregroundColor: color,
                                  child: const Icon(Icons.gavel),
                                ),
                                const Spacer(),
                                Text(topic.mastery.round().toString() + '%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const Spacer(),
                            Text(topic.topic, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: topic.mastery / 100, minHeight: 7, color: color, borderRadius: BorderRadius.circular(10)),
                            const SizedBox(height: 6),
                            Text(topic.total.toString() + ' questions', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<String> topics = const [];
  String? topic;
  late double sessionSize;
  late bool negativeMarking;

  @override
  void initState() {
    super.initState();
    sessionSize = (widget.prefs.getInt('session_size') ?? 15).toDouble();
    negativeMarking = widget.prefs.getBool('negative_marking') ?? false;
    AppDatabase.instance.topics().then((value) {
      if (!mounted) return;
      setState(() {
        topics = value;
        if (topics.isNotEmpty) topic = topics.first;
      });
    });
  }

  Future<void> start(PracticeMode mode) async {
    await widget.prefs.setInt('session_size', sessionSize.round());
    await widget.prefs.setBool('negative_marking', negativeMarking);
    final questions = await AppDatabase.instance.buildSession(
      mode: mode,
      sessionSize: sessionSize.round(),
      dailyNewLimit: widget.prefs.getInt('daily_new_limit') ?? 30,
      topic: topic,
    );
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions match this practice mode yet.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          mode: mode,
          prefs: widget.prefs,
          negativeMarking: mode == PracticeMode.mockExam && negativeMarking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Practice', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Choose a drill. Everything below works from the local SQLite database.'),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session size: ' + sessionSize.round().toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                Slider(
                  value: sessionSize,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  onChanged: (value) => setState(() => sessionSize = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: topic,
                  decoration: const InputDecoration(labelText: 'Topic'),
                  items: topics.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setState(() => topic = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mock exam negative marking'),
                  subtitle: const Text('-0.25 for every wrong answer'),
                  value: negativeMarking,
                  onChanged: (value) => setState(() => negativeMarking = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ModeTile(icon: Icons.today, title: 'Daily Review', subtitle: 'Due cards, then new cards', onTap: () => start(PracticeMode.dailyReview)),
        ModeTile(icon: Icons.topic_outlined, title: 'Topic Practice', subtitle: topic ?? 'Choose a topic', onTap: topics.isEmpty ? null : () => start(PracticeMode.topicPractice)),
        ModeTile(icon: Icons.error_outline, title: 'Wrong-Answers Only', subtitle: 'Questions you most recently missed', color: amber, onTap: () => start(PracticeMode.wrongAnswers)),
        ModeTile(icon: Icons.star_border, title: 'Bookmarked', subtitle: 'Only your saved questions', onTap: () => start(PracticeMode.bookmarked)),
        ModeTile(icon: Icons.timer_outlined, title: 'Mock Exam', subtitle: 'Timed at 60 seconds per question', onTap: () => start(PracticeMode.mockExam)),
        ModeTile(icon: Icons.shuffle, title: 'Random 50', subtitle: '50 random questions from the bank', onTap: () => start(PracticeMode.random50)),
      ],
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.questions,
    required this.mode,
    required this.prefs,
    this.negativeMarking = false,
  });

  final List<Question> questions;
  final PracticeMode mode;
  final SharedPreferences prefs;
  final bool negativeMarking;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  String? selected;
  bool answered = false;
  bool bookmarked = false;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  late DateTime started;
  late List<MapEntry<String, String>> options;
  Timer? timer;
  int? secondsLeft;

  Question get question => widget.questions[index];
  bool get isMock => widget.mode == PracticeMode.mockExam;

  @override
  void initState() {
    super.initState();
    if (isMock) {
      secondsLeft = widget.questions.length * 60;
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (secondsLeft! <= 1) {
          timer?.cancel();
          finish();
        } else {
          setState(() => secondsLeft = secondsLeft! - 1);
        }
      });
    }
    prepare();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> prepare() async {
    started = DateTime.now();
    selected = null;
    answered = false;
    options = question.options.entries.toList();
    if (widget.prefs.getBool('shuffle_options') ?? false) options.shuffle();
    bookmarked = await AppDatabase.instance.isBookmarked(question.id);
    if (mounted) setState(() {});
  }

  void choose(String key) {
    if (answered) return;
    final correct = key == question.answer;
    setState(() {
      selected = key;
      answered = true;
      if (correct) {
        correctAnswers++;
      } else {
        wrongAnswers++;
      }
    });
  }

  Future<void> record(ReviewRating rating) async {
    if (!answered || selected == null) return;
    await AppDatabase.instance.recordAnswer(
      question: question,
      selectedAnswer: selected!,
      correct: selected == question.answer,
      rating: rating,
      timeMs: DateTime.now().difference(started).inMilliseconds,
      mode: widget.mode,
    );
    if (!mounted) return;
    if (index == widget.questions.length - 1) {
      await finish();
    } else {
      setState(() => index++);
      await prepare();
    }
  }

  Future<void> finish() async {
    timer?.cancel();
    if (!mounted) return;
    final score = correctAnswers - (widget.negativeMarking ? wrongAnswers * .25 : 0);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Correct: ' + correctAnswers.toString()),
            Text('Wrong: ' + wrongAnswers.toString()),
            Text('Score: ' + score.toStringAsFixed(2) + ' / ' + widget.questions.length.toString()),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> editNote() async {
    final controller = TextEditingController(text: await AppDatabase.instance.noteFor(question.id));
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note • #' + question.id.toString()),
        content: TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(hintText: 'Write your note…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (save == true) await AppDatabase.instance.saveNote(question.id, controller.text.trim());
    controller.dispose();
  }

  Color? feedbackColor(String key) {
    if (!answered) return null;
    if (key == question.answer) return green;
    if (key == selected) return red;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / widget.questions.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        title: LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(10)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: Text((index + 1).toString() + '/' + widget.questions.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(icon: Icons.sell_outlined, text: question.topic),
              if (isMock && secondsLeft != null) Pill(icon: Icons.timer_outlined, text: formatSeconds(secondsLeft!), color: amber),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('TASK', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                      const Spacer(),
                      IconButton(onPressed: editNote, icon: const Icon(Icons.edit_note_outlined)),
                      IconButton(
                        onPressed: () async {
                          await AppDatabase.instance.toggleBookmark(question.id);
                          if (mounted) setState(() => bookmarked = !bookmarked);
                        },
                        icon: Icon(bookmarked ? Icons.star : Icons.star_border, color: bookmarked ? amber : null),
                      ),
                    ],
                  ),
                  Text('Question #' + question.id.toString(), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 10),
                  Text(question.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.4)),
                  if (question.image != null) ...[
                    const SizedBox(height: 14),
                    QuestionImage(path: question.image!),
                  ],
                  if (question.source.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(question.source, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final option in options) ...[
            OptionButton(
              keyText: option.key,
              text: option.value,
              color: feedbackColor(option.key),
              onTap: () => choose(option.key),
            ),
            const SizedBox(height: 10),
          ],
          if (answered) ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(selected == question.answer ? Icons.check_circle : Icons.cancel, color: selected == question.answer ? green : red),
                        const SizedBox(width: 8),
                        Text(selected == question.answer ? 'Correct' : 'Incorrect', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(question.explanation.isEmpty ? 'Correct answer: ' + question.answer : question.explanation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isMock)
              FilledButton.icon(
                onPressed: () => record(selected == question.answer ? ReviewRating.good : ReviewRating.again),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              )
            else
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => record(ReviewRating.again), child: const Text('Again'))),
                  const SizedBox(width: 6),
                  Expanded(child: OutlinedButton(onPressed: () => record(ReviewRating.hard), child: const Text('Hard'))),
                  const SizedBox(width: 6),
                  Expanded(child: FilledButton.tonal(onPressed: () => record(ReviewRating.good), child: const Text('Good'))),
                  const SizedBox(width: 6),
                  Expanded(child: FilledButton(onPressed: () => record(ReviewRating.easy), child: const Text('Easy'))),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StatsSnapshot>(
      future: AppDatabase.instance.stats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data!;
        final achievements = achievementList(stats);
        final unlocked = achievements.where((item) => item.$2).length;
        final weak = [...stats.topics]..sort((a, b) => a.mastery.compareTo(b.mastery));

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Stats', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MetricCard(label: 'Reviews', value: stats.totalReviews.toString(), icon: Icons.repeat),
                MetricCard(label: 'Accuracy', value: stats.accuracy.toStringAsFixed(1) + '%', icon: Icons.check_circle_outline),
                MetricCard(label: 'Streak', value: stats.currentStreak.toString() + 'd', icon: Icons.local_fire_department_outlined),
                MetricCard(label: 'Avg time', value: (stats.averageTimeMs / 1000).toStringAsFixed(1) + 's', icon: Icons.speed),
              ],
            ),
            const SizedBox(height: 22),
            Text('Review activity • 12 weeks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Heatmap(activity: stats.activity))),
            const SizedBox(height: 22),
            Text('Retention • last 14 days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 18, 14, 10), child: RetentionBars(data: stats.retention))),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Text('Achievements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                Text(unlocked.toString() + '/24 unlocked', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: achievements.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.05),
              itemBuilder: (context, i) {
                final item = achievements[i];
                return Card(
                  child: Opacity(
                    opacity: item.$2 ? 1 : .4,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.$2 ? item.$3 : Icons.lock_outline, color: item.$2 ? green : null),
                          const SizedBox(height: 6),
                          Text(item.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Predicted exam score', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(stats.predictedScore.toStringAsFixed(1) + '%', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                    const Text('Based on recorded review accuracy; this is not a calibrated exam forecast.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Weakest topics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            for (final topic in weak.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(topic.topic),
                subtitle: LinearProgressIndicator(value: topic.mastery / 100, color: topic.mastery >= 50 ? green : amber),
                trailing: Text(topic.mastery.round().toString() + '%'),
              ),
          ],
        );
      },
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final controller = TextEditingController();
  String filter = 'all';
  late Future<List<Question>> future;

  @override
  void initState() {
    super.initState();
    search();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void search() {
    setState(() {
      future = AppDatabase.instance.librarySearch(query: controller.text, filter: filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Library', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search text or question #',
                  suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.arrow_forward)),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'wrong', label: Text('Wrong')),
                    ButtonSegment(value: 'bookmarked', label: Text('Saved')),
                    ButtonSegment(value: 'unseen', label: Text('Unseen')),
                    ButtonSegment(value: 'mastered', label: Text('Mastered')),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) {
                    filter = value.first;
                    search();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Question>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final questions = snapshot.data!;
              if (questions.isEmpty) return const Center(child: Text('No questions match this filter.'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  return Card(
                    child: ListTile(
                      title: Text('#' + q.id.toString() + ' • ' + q.topic, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionDetailScreen(question: q))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class QuestionDetailScreen extends StatelessWidget {
  const QuestionDetailScreen({super.key, required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Question #' + question.id.toString())),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Pill(icon: Icons.sell_outlined, text: question.topic),
          const SizedBox(height: 12),
          Text(question.question, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.4)),
          const SizedBox(height: 18),
          for (final option in question.options.entries)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(option.key)),
                title: Text(option.value),
                trailing: option.key == question.answer ? const Icon(Icons.check_circle, color: green) : null,
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explanation', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(question.explanation.isEmpty ? 'Correct answer: ' + question.answer : question.explanation),
                  if (question.source.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Source: ' + question.source, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.prefs,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onDataChanged,
  });

  final SharedPreferences prefs;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onDataChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool reminder;
  late bool shuffle;
  late double newLimit;

  @override
  void initState() {
    super.initState();
    reminder = widget.prefs.getBool('daily_reminder') ?? true;
    shuffle = widget.prefs.getBool('shuffle_options') ?? false;
    newLimit = (widget.prefs.getInt('daily_new_limit') ?? 30).toDouble();
  }

  Future<void> importFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty || !mounted) return;
    int inserted = 0;
    int skipped = 0;
    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final outcome = await AppDatabase.instance.importJsonText(utf8.decode(bytes));
        inserted += outcome.inserted;
        skipped += outcome.skipped;
      }
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ' + inserted.toString() + '; skipped ' + skipped.toString() + ' duplicate IDs.')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: ' + error.toString())));
    }
  }

  Future<void> reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('Questions remain, but attempts, streaks, notes, bookmarks and review history will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      await AppDatabase.instance.resetProgress();
      widget.onDataChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        const SectionTitle('Account'),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.account_circle_outlined),
                title: Text('Offline account'),
                subtitle: Text('Progress is stored on this device. Cloud sync is optional.'),
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync now'),
                subtitle: const Text('Cloud adapter not configured'),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud sync is not configured yet.'))),
              ),
              const ListTile(leading: Icon(Icons.logout), title: Text('Log out'), subtitle: Text('No cloud account is signed in'), enabled: false),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {widget.themeMode},
              onSelectionChanged: (value) => widget.onThemeChanged(value.first),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Practice'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Shuffle option order'),
                subtitle: const Text('Original question number stays visible'),
                value: shuffle,
                onChanged: (value) async {
                  setState(() => shuffle = value);
                  await widget.prefs.setBool('shuffle_options', value);
                },
              ),
              ListTile(
                title: Text('Daily new-card limit: ' + newLimit.round().toString()),
                subtitle: Slider(
                  value: newLimit,
                  min: 5,
                  max: 60,
                  divisions: 11,
                  onChanged: (value) => setState(() => newLimit = value),
                  onChangeEnd: (value) => widget.prefs.setInt('daily_new_limit', value.round()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Notifications'),
        Card(
          child: SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text('Preferred time: 6:00 PM'),
            value: reminder,
            onChanged: (value) async {
              setState(() => reminder = value);
              await widget.prefs.setBool('daily_reminder', value);
            },
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Data'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Import question bank'),
                subtitle: const Text('Select one or many JSON files'),
                onTap: importFiles,
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export progress'),
                onTap: () async {
                  final path = await AppDatabase.instance.exportProgress();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to ' + path)));
                },
              ),
              ListTile(leading: const Icon(Icons.restart_alt, color: red), title: const Text('Reset progress'), onTap: reset),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Offline-first • SQLite • SM-2-style scheduling', textAlign: TextAlign.center),
      ],
    );
  }
}

class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.keyText,
    required this.text,
    required this.color,
    required this.onTap,
  });

  final String keyText;
  final String text;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color?.withValues(alpha: .11) ?? Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color ?? Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color?.withValues(alpha: .18),
                foregroundColor: color,
                child: Text(keyText, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
              if (color != null) Icon(color == green ? Icons.check_circle : Icons.cancel, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionImage extends StatelessWidget {
  const QuestionImage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.contain);
    return Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }
}

class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          leading: CircleAvatar(backgroundColor: c.withValues(alpha: .1), foregroundColor: c, child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c)),
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 46) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.activity});
  final Map<DateTime, int> activity;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final days = List.generate(84, (i) => end.subtract(Duration(days: 83 - i)));
    final total = activity.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(total.toString() + ' reviews in 12 weeks', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 12, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemBuilder: (context, i) {
            final count = activity[days[i]] ?? 0;
            final opacity = count == 0 ? .08 : .22 + (count.clamp(1, 8).toDouble() / 8) * .78;
            return Tooltip(
              message: DateFormat.MMMd().format(days[i]) + ': ' + count.toString() + ' reviews',
              child: DecoratedBox(
                decoration: BoxDecoration(color: green.withValues(alpha: opacity), borderRadius: BorderRadius.circular(3)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class RetentionBars extends StatelessWidget {
  const RetentionBars({super.key, required this.data});
  final Map<DateTime, double> data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.entries.map((entry) {
          final value = entry.value;
          final color = value >= .7 ? green : amber;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: DateFormat.Md().format(entry.key) + ': ' + (value * 100).round().toString() + '%',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: value == 0 ? .04 : value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(DateFormat.d().format(entry.key), style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

List<(String, bool, IconData)> achievementList(StatsSnapshot s) {
  final r = s.totalReviews;
  final streak = s.currentStreak;
  final accuracy = s.accuracy;
  return [
    ('First Review', r >= 1, Icons.play_arrow),
    ('10 Reviews', r >= 10, Icons.looks_one),
    ('50 Reviews', r >= 50, Icons.filter_5),
    ('100 Reviews', r >= 100, Icons.emoji_events_outlined),
    ('250 Reviews', r >= 250, Icons.bolt),
    ('500 Reviews', r >= 500, Icons.stars_outlined),
    ('1000 Questions', r >= 1000, Icons.workspace_premium_outlined),
    ('2500 Reviews', r >= 2500, Icons.military_tech_outlined),
    ('5000 Reviews', r >= 5000, Icons.diamond_outlined),
    ('2-day streak', streak >= 2, Icons.local_fire_department_outlined),
    ('3-day streak', streak >= 3, Icons.local_fire_department_outlined),
    ('7-day streak', streak >= 7, Icons.local_fire_department),
    ('14-day streak', streak >= 14, Icons.whatshot),
    ('30-day streak', streak >= 30, Icons.rocket_launch_outlined),
    ('60-day streak', streak >= 60, Icons.rocket_launch),
    ('100-day streak', streak >= 100, Icons.auto_awesome),
    ('60% Accuracy', r >= 20 && accuracy >= 60, Icons.check),
    ('70% Accuracy', r >= 30 && accuracy >= 70, Icons.check_circle_outline),
    ('80% Accuracy', r >= 50 && accuracy >= 80, Icons.check_circle),
    ('90% Accuracy', r >= 100 && accuracy >= 90, Icons.verified_outlined),
    ('95% Accuracy', r >= 200 && accuracy >= 95, Icons.verified),
    ('Fast 20', r >= 20 && s.averageTimeMs > 0 && s.averageTimeMs <= 20000, Icons.speed),
    ('All Topics', s.topics.length >= 4 && s.topics.every((t) => t.attempted > 0), Icons.category_outlined),
    ('Mastery 80', s.topics.isNotEmpty && s.topics.any((t) => t.mastery >= 80), Icons.school_outlined),
  ];
}

String formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return minutes.toString() + ':' + remaining.toString().padLeft(2, '0');
}
