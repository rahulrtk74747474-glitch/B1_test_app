import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads.dart';

/// Reusable test setup for Home subjects, Practice modes and Review buckets.
/// All UI is scrollable so the ad never obscures controls on small phones.
Future<int?> showQuestionCountDialog(
  BuildContext context, {
  required String title,
  required int available,
  required int preferred,
  String? description,
}) async {
  if (available <= 0) return null;
  final initial = preferred.clamp(1, available);
  final controller = TextEditingController(text: initial.toString());
  String? error;
  final selection = await showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(dialogContext).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(description ?? '$available questions available',
                    style: Theme.of(dialogContext).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  // AdMob medium rectangle (300x250) where space allows,
                  // otherwise use a responsive small banner. Never gate study on ads.
                  const Center(child: QuestionBanner(large: true)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: false,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'How many questions to attempt?',
                      helperText: 'Choose from 1 to $available',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() => error = null),
                    onSubmitted: (_) {
                      final count = int.tryParse(controller.text.trim());
                      if (count == null || count < 1 || count > available) {
                        setDialogState(() => error = 'Enter a number from 1 to $available');
                      } else {
                        Navigator.of(dialogContext).pop(count);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start test'),
                      onPressed: () {
                        final count = int.tryParse(controller.text.trim());
                        if (count == null || count < 1 || count > available) {
                          setDialogState(() => error = 'Enter a number from 1 to $available');
                          return;
                        }
                        Navigator.of(dialogContext).pop(count);
                      },
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  controller.dispose();
  return selection;
}
