import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads.dart';

/// Reusable question-count setup across Home, Practice and Review.
/// The input controller belongs to the route's widget, not the caller, so
/// closing animations cannot access an already-disposed controller.
Future<int?> showQuestionCountDialog(
  BuildContext context, {
  required String title,
  required int available,
  required int preferred,
  String? description,
}) {
  if (available <= 0) return Future<int?>.value(null);
  return showDialog<int>(
    context: context,
    builder: (_) => _QuestionCountDialog(
      title: title, available: available, preferred: preferred,
      description: description,
    ),
  );
}

class _QuestionCountDialog extends StatefulWidget {
  const _QuestionCountDialog({
    required this.title,
    required this.available,
    required this.preferred,
    this.description,
  });
  final String title;
  final int available;
  final int preferred;
  final String? description;

  @override
  State<_QuestionCountDialog> createState() => _QuestionCountDialogState();
}

class _QuestionCountDialogState extends State<_QuestionCountDialog> {
  late final TextEditingController controller;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.preferred.clamp(1, widget.available).toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void start() {
    final count = int.tryParse(controller.text.trim());
    if (count == null || count < 1 || count > widget.available) {
      setState(() => error = 'Enter a number from 1 to ${widget.available}');
      return;
    }
    Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(widget.description ??
                '${widget.available} questions available',
                style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              // 300x250 medium rectangle where space allows, otherwise compact.
              // Test selection always works if no advertisement loads.
              const Center(child: QuestionBanner(large: true)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'How many questions to attempt?',
                  helperText: 'Choose from 1 to ${widget.available}',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => error = null),
                onSubmitted: (_) => start(),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start test'),
                  onPressed: start,
                )),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}
