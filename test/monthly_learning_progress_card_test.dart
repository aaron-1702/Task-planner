import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_task_planner/presentation/widgets/monthly_learning_progress_card.dart';

void main() {
  testWidgets('shows progress details when a monthly goal exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthlyLearningProgressCard(
            title: 'Monthly learning goal',
            monthLabel: 'May 2026',
            learned: Duration(hours: 6),
            goal: Duration(hours: 10),
            remaining: Duration(hours: 4),
            progress: 0.6,
            actionLabel: 'Edit goal',
          ),
        ),
      ),
    );

    expect(find.text('6h / 10h'), findsOneWidget);
    expect(find.text('4h remaining this month'), findsOneWidget);
    expect(find.text('60% of monthly goal completed'), findsOneWidget);
  });

  testWidgets('shows empty state when no monthly goal exists', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonthlyLearningProgressCard(
            title: 'Monthly learning goal',
            monthLabel: 'May 2026',
            learned: Duration.zero,
            goal: Duration.zero,
            remaining: Duration.zero,
            progress: 0,
            actionLabel: 'Set goal',
          ),
        ),
      ),
    );

    expect(find.text('No monthly learning goal has been set yet.'), findsOneWidget);
    expect(
      find.text('Set a target in the study timer to track your progress here.'),
      findsOneWidget,
    );
  });
}