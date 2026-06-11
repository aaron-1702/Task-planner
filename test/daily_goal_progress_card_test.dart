import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_task_planner/presentation/blocs/daily_goal/daily_goal_cubit.dart';
import 'package:smart_task_planner/presentation/widgets/daily_goal_progress_card.dart';

void main() {
  testWidgets('shows checklist progress and goals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyGoalProgressCard(
            title: 'Daily goals',
            dateLabel: 'Thursday, June 11',
            goals: [
              DailyGoalForDate(
                id: '1',
                title: 'Inbox zero',
                isCompleted: true,
              ),
              DailyGoalForDate(
                id: '2',
                title: 'Workout',
                isCompleted: false,
              ),
            ],
            completedCount: 1,
            progress: 0.5,
            actionLabel: 'Edit goals',
          ),
        ),
      ),
    );

    expect(find.text('1 / 2 completed today'), findsOneWidget);
    expect(find.text('1 still open today'), findsOneWidget);
    expect(find.text('Inbox zero'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
  });

  testWidgets('shows empty state when no daily goals exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyGoalProgressCard(
            title: 'Daily goals',
            dateLabel: 'Thursday, June 11',
            goals: [],
            completedCount: 0,
            progress: 0,
            actionLabel: 'Set goals',
          ),
        ),
      ),
    );

    expect(find.text('No daily goals have been set yet.'), findsOneWidget);
    expect(
      find.text(
        'Create a short recurring checklist for the things you want to complete every day.',
      ),
      findsOneWidget,
    );
  });
}