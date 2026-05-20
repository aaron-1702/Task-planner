import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_task_planner/domain/entities/work_entry.dart';
import 'package:smart_task_planner/presentation/pages/worklog/worklog_page.dart';

void main() {
  testWidgets('EntryTile shows the entry date in month view', (tester) async {
    final entry = WorkEntry(
      id: '1',
      userId: 'user-1',
      date: DateTime(2026, 5, 20),
      startTime: DateTime.utc(2026, 5, 20, 8, 0),
      endTime: DateTime.utc(2026, 5, 20, 10, 30),
      breakMinutes: 15,
      note: 'Planning session',
      createdAt: DateTime.utc(2026, 5, 20),
      updatedAt: DateTime.utc(2026, 5, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryTile(
            entry: entry,
            showDate: true,
          ),
        ),
      ),
    );

    expect(find.text('20.05.2026'), findsOneWidget);
  });

  testWidgets('EntryTile can hide the date outside month view', (tester) async {
    final entry = WorkEntry(
      id: '1',
      userId: 'user-1',
      date: DateTime(2026, 5, 20),
      startTime: DateTime.utc(2026, 5, 20, 8, 0),
      endTime: DateTime.utc(2026, 5, 20, 10, 30),
      createdAt: DateTime.utc(2026, 5, 20),
      updatedAt: DateTime.utc(2026, 5, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryTile(
            entry: entry,
            showDate: false,
          ),
        ),
      ),
    );

    expect(find.text('20.05.2026'), findsNothing);
  });
}
