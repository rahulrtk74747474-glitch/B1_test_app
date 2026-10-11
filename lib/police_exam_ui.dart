import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'ads.dart';
import 'police_exam_repository.dart';

class PoliceExamHub extends StatefulWidget {
  const PoliceExamHub({super.key});
  @override
  State<PoliceExamHub> createState() => _PoliceExamHubState();
}

class _PoliceExamHubState extends State<PoliceExamHub> {
  final countController = TextEditingController(text: '100');
  bool negative = false, timed = false, loading = false;
  late Future<Map<String, int>> inventory;
  late Future<List<PoliceExamRecord>> history;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    inventory = PoliceExamRepository.instance.subjectInventory();
    history = PoliceExamRepository.instance.history();
  }

  @override
  void dispose() {
    countController.dispose();
    super.dispose();
  }

  Future<void> start() async {
    final count = int.tryParse(countController.text.trim());
    final available = (await inventory).values.fold<int>(0, (sum, n) => sum + n);
    if (!mounted) return;
    if (count == null || count < 1 || count > available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a number from 1 to $available.'),
      ));
      return;
    }
    setState(() => loading = true);
    try {
      final questions = await PoliceExamRepository.instance.balancedRandomQuestions(count);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PoliceBalancedExamScreen(
          questions: questions, negativeMarking: negative, timed: timed,
        ),
      ));
      if (mounted) setState(refresh);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start test: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Police B1 Test')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Text('Balanced Random Exam', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Choose the exact number of questions. Subjects receive an equal share wherever enough questions exist; shortages are redistributed. Answers stay hidden until submission.'),
      const SizedBox(height: 12),
      const QuestionBanner(),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, int>>(
        future: inventory,
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final counts = snapshot.data!;
          final total = counts.values.fold<int>(0, (sum, n) => sum + n);
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${counts.length} subjects • $total questions available',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: countController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of test questions', prefixIcon: Icon(Icons.numbers))),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Time limit'), subtitle: const Text('60 seconds per question'),
                value: timed, onChanged: (v) => setState(() => timed = v)),
              SwitchListTile(title: const Text('Negative marking'), subtitle: const Text('-0.25 for each wrong answer'),
                value: negative, onChanged: (v) => setState(() => negative = v)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: loading || total == 0 ? null : start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(loading ? 'Preparing…' : 'Start random test'),
              )),
            ],
          )));
        },
      ),
      const SizedBox(height: 24),
      Text('Past tests & improvement', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      FutureBuilder<List<PoliceExamRecord>>(future: history, builder: (_, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final exams = snapshot.data!;
        if (exams.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18),
          child: Text('No previous exams yet. Your test history will appear here and remain saved offline.')));
        return Column(children: [
          for (final e in exams) Card(child: ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: Text('${e.correct}/${e.total} correct • ${e.accuracy.toStringAsFixed(1)}% of attempts'),
            subtitle: Text('${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(e.startedAt))} • ${e.skipped} skipped'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PoliceExamResultScreen(record: e),
            )),
          )),
        ]);
      }),
      const SizedBox(height: 22),
      Text('Subjects needing attention', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      FutureBuilder<List<PoliceSubjectResult>>(
        future: PoliceExamRepository.instance.overallSubjectResults(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final items = [...snapshot.data!]..sort((a, b) => a.accuracy.compareTo(b.accuracy));
          if (items.isEmpty) return const Text('Complete a test to see your weak subjects.');
          return Column(children: [
            for (final item in items.take(8)) PoliceSubjectBar(result: item),
          ]);
        },
      ),
    ]),
  );
}

class PoliceBalancedExamScreen extends StatefulWidget {
  const PoliceBalancedExamScreen({
    super.key, required this.questions,
    required this.negativeMarking, required this.timed,
  });
  final List<Question> questions;
  final bool negativeMarking, timed;
  @override
  State<PoliceBalancedExamScreen> createState() => _PoliceBalancedExamScreenState();
}

class _PoliceBalancedExamScreenState extends State<PoliceBalancedExamScreen> {
  final answers = <int, String>{};
  late DateTime started;
  Timer? timer;
  int index = 0, seconds = 0;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    started = DateTime.now();
    if (widget.timed) {
      seconds = widget.questions.length * 60;
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (seconds <= 1) {
          timer?.cancel();
          submit(force: true);
        } else {
          setState(() => seconds--);
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<bool> confirmExit() async {
    if (saving) return false;
    return await showDialog<bool>(context: context, builder: (dialog) =>
      AlertDialog(title: const Text('Leave exam?'),
        content: const Text('This exam has not been submitted and your answers will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Continue test')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Leave')),
        ],
      )) ?? false;
  }

  Future<void> submit({bool force = false}) async {
    if (saving) return;
    if (!force) {
      final proceed = await showDialog<bool>(
        context: context, builder: (dialog) => AlertDialog(
          title: const Text('Submit exam?'),
          content: Text('${answers.length} of ${widget.questions.length} answered. Unanswered questions will count as skipped.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Continue')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Submit')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() => saving = true);
    timer?.cancel();
    try {
      final result = await PoliceExamRepository.instance.saveExam(
        questions: widget.questions,
        selected: answers,
        started: started,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        negativeMarking: widget.negativeMarking,
      );
      if (!mounted) return;
      // The result page is shown first; when it is closed, show a capped
      // interstitial at the natural transition back to the exam dashboard.
      await Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PoliceExamResultScreen(record: result),
      ));
      await AdsManager.instance.maybeShowAfterResult();
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save exam: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[index];
    return PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) async {
      if (didPop || saving) return;
      if (await confirmExit() && context.mounted) Navigator.pop(context);
    }, child: Scaffold(
      appBar: AppBar(
        title: Text('Question ${index + 1} / ${widget.questions.length}'),
        actions: [
          if (widget.timed) Center(child: Padding(padding: const EdgeInsets.all(12),
            child: Text('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        LinearProgressIndicator(value: (index + 1) / widget.questions.length),
        const QuestionBanner(),
        const SizedBox(height: 15),
        Text(q.topic, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(q.question, style: Theme.of(context).textTheme.titleLarge),
        for (final imagePath in q.imagePaths) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PoliceExamImage(path: imagePath)),
        const SizedBox(height: 20),
        for (final key in const ['A', 'B', 'C', 'D'])
          Card(child: RadioListTile<String>(
            value: key, groupValue: answers[q.id],
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$key. ${q.options[key] ?? ''}'),
              if (q.optionImages[key] != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PoliceExamImage(path: q.optionImages[key]!)),
            ]),
            onChanged: saving ? null : (v) => setState(() {
              if (v != null) answers[q.id] = v;
            }),
          )),
        const SizedBox(height: 8),
        Text('${answers.length} / ${widget.questions.length} answered'),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: index == 0 ? null : () => setState(() => index--),
            child: const Text('Previous'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(
            onPressed: saving ? null : index + 1 == widget.questions.length
              ? () => submit() : () => setState(() => index++),
            child: Text(index + 1 == widget.questions.length ? 'Submit test' : 'Next'))),
        ]),
        TextButton(onPressed: saving ? null : () => submit(), child: const Text('Finish test now')),
      ]),
    ));
  }
}

class PoliceSubjectBar extends StatelessWidget {
  const PoliceSubjectBar({super.key, required this.result});
  final PoliceSubjectResult result;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(result.topic, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text('${result.correct}/${result.total} • ${result.accuracy.toStringAsFixed(1)}%'),
      ]),
      const SizedBox(height: 5),
      LinearProgressIndicator(value: result.accuracy / 100, minHeight: 7, borderRadius: BorderRadius.circular(12)),
      if (result.improvement != null) Text(
        '${result.improvement! >= 0 ? '+' : ''}${result.improvement!.toStringAsFixed(1)} percentage points versus earlier tests',
        style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}

class PoliceExamResultScreen extends StatelessWidget {
  const PoliceExamResultScreen({super.key, required this.record});
  final PoliceExamRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Exam #${record.id} result')),
    body: FutureBuilder<List<PoliceSubjectResult>>(
      future: PoliceExamRepository.instance.subjectResults(record.id),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final results = [...snapshot.data!]..sort((a, b) => a.accuracy.compareTo(b.accuracy));
        return ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            const Icon(Icons.emoji_events_outlined, size: 44),
            Text('${record.score.toStringAsFixed(2)} / ${record.total}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('Correct ${record.correct} • Wrong ${record.wrong} • Skipped ${record.skipped}'),
            Text('Accuracy ${record.accuracy.toStringAsFixed(1)}% of attempted questions'),
            Text('Duration ${Duration(milliseconds: record.durationMs).inMinutes} minutes'),
          ]))),
          const SizedBox(height: 20),
          Text('Subject-wise performance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final result in results) PoliceSubjectBar(result: result),
          const SizedBox(height: 18),
          if (results.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Text('Revision priority: ${results.take(3).map((e) => e.topic).join(', ')}. Focus on the subjects with the lowest scores, then take another test to measure improvement.'))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PoliceExamAnswerReview(examId: record.id))),
            icon: const Icon(Icons.fact_check_outlined), label: const Text('Review questions and answers')),
        ]);
      },
    ),
  );
}

class PoliceExamAnswerReview extends StatelessWidget {
  const PoliceExamAnswerReview({super.key, required this.examId});
  final int examId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Answer review')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: PoliceExamRepository.instance.answersForExam(examId),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return ListView.builder(itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            final answer = r['selected_answer'] as String?;
            return Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ${r['topic']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text((r['question'] as String?) ?? 'Question #${r['question_id']}'),
                  const SizedBox(height: 8),
                  for (final k in const ['A', 'B', 'C', 'D'])
                    Text('$k. ${r['option_${k.toLowerCase()}'] ?? ''}'),
                  const SizedBox(height: 8),
                  Text('Your answer: ${answer ?? 'Skipped'} • Correct: ${r['correct_answer']}',
                    style: TextStyle(fontWeight: FontWeight.bold,
                      color: answer == r['correct_answer'] ? Colors.green : Colors.red)),
                ])));
          },
        );
      },
    ),
  );
}

/// Preserve zoomable image-based questions in the balanced exam flow.
class PoliceExamImage extends StatelessWidget {
  const PoliceExamImage({super.key, required this.path});
  final String path;

  Widget preview({bool full = false}) {
    final image = path.startsWith('assets/')
        ? Image.asset(path, fit: BoxFit.contain)
        : Image.file(File(path), fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Image unavailable'));
    return full ? InteractiveViewer(minScale: .6, maxScale: 5, child: image) : image;
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(context: context, builder: (dialog) =>
      Dialog(child: Stack(children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .65,
          width: double.infinity, child: preview(full: true)),
        Positioned(right: 0, top: 0, child: IconButton(
          icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialog))),
      ]))),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: preview(),
    ),
  );
}
