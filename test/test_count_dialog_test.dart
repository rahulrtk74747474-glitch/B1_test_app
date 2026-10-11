import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b1_test_app/test_count_dialog.dart';
import 'package:b1_test_app/police_exam_repository.dart';

void main() {
  testWidgets('question-count dialog accepts exact chosen count', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          selected = await showQuestionCountDialog(context,
            title: 'Police Station Work', available: 1537, preferred: 15);
        }, child: const Text('Open count'),
      )),
    )));
    await tester.tap(find.text('Open count'));
    await tester.pumpAndSettle();
    expect(find.text('How many questions to attempt?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
    expect(selected, 2);
  });

  testWidgets('question-count dialog rejects more than available', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          selected = await showQuestionCountDialog(context,
            title: 'Hard Revision', available: 2, preferred: 15);
        }, child: const Text('Open count'),
      )),
    )));
    await tester.tap(find.text('Open count'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '99');
    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 2'), findsOneWidget);
    expect(selected, isNull);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  test('accuracy excludes skipped questions while completion includes them', () {
    const data = PoliceSubjectResult(
      topic: 'BNS', total: 10, attempted: 2,
      correct: 1, wrong: 1, previousAccuracy: 40);
    expect(data.accuracy, 50);
    expect(data.skipped, 8);
    expect(data.improvement, 10);
  });
}
