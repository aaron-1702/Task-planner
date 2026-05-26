import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:smart_task_planner/core/errors/failures.dart';
import 'package:smart_task_planner/domain/entities/learning_entry.dart';
import 'package:smart_task_planner/domain/repositories/learning_entry_repository.dart';
import 'package:smart_task_planner/domain/usecases/learning_entry_usecases.dart';
import 'package:smart_task_planner/presentation/blocs/learninglog/learninglog_bloc.dart';
import 'package:smart_task_planner/presentation/pages/learninglog/learninglog_page.dart';

class _FakeLearningEntryRepository implements LearningEntryRepository {
  final _controller = StreamController<List<LearningEntry>>.broadcast();
  final List<LearningEntry> _entries = [];

  _FakeLearningEntryRepository([List<LearningEntry> seed = const []]) {
    _entries.addAll(seed);
    _controller.add(List<LearningEntry>.from(_entries));
  }

  @override
  Future<Either<Failure, LearningEntry>> createEntry(
      LearningEntry entry) async {
    _entries.add(entry);
    _controller.add(List<LearningEntry>.from(_entries));
    return Right(entry);
  }

  @override
  Future<Either<Failure, Unit>> deleteEntry(
      String entryId, String userId) async {
    _entries.removeWhere((e) => e.id == entryId && e.userId == userId);
    _controller.add(List<LearningEntry>.from(_entries));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> syncFromRemote(String userId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, LearningEntry>> updateEntry(
      LearningEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
      _controller.add(List<LearningEntry>.from(_entries));
    }
    return Right(entry);
  }

  @override
  Stream<List<LearningEntry>> watchEntriesByUser(String userId) {
    return () async* {
      yield _entries.where((e) => e.userId == userId && !e.isDeleted).toList();
      yield* _controller.stream.map(
        (list) =>
            list.where((e) => e.userId == userId && !e.isDeleted).toList(),
      );
    }();
  }

  @override
  Stream<List<LearningEntry>> watchEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return watchEntriesByUser(userId).map(
      (list) => list
          .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
          .toList(),
    );
  }

  void dispose() {
    _controller.close();
  }
}

LearninglogBloc _createBloc([_FakeLearningEntryRepository? repository]) {
  final repo = repository ?? _FakeLearningEntryRepository();
  return LearninglogBloc(
    WatchLearningEntriesUseCase(repo),
    CreateLearningEntryUseCase(repo),
    UpdateLearningEntryUseCase(repo),
    DeleteLearningEntryUseCase(repo),
    SyncLearningEntriesUseCase(repo),
    const ExportLearningEntriesCsvUseCase(),
  );
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'de_DE';
    await initializeDateFormatting('de_DE');
  });

  testWidgets('LearningEntryTile shows date in month mode', (tester) async {
    final entry = LearningEntry(
      id: '1',
      userId: 'user-1',
      date: DateTime(2026, 5, 20),
      startTime: DateTime.utc(2026, 5, 20, 8, 0),
      endTime: DateTime.utc(2026, 5, 20, 10, 0),
      breakMinutes: 10,
      topic: 'Flutter',
      note: 'Widgets',
      createdAt: DateTime.utc(2026, 5, 20),
      updatedAt: DateTime.utc(2026, 5, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningEntryTile(entry: entry, showDate: true),
        ),
      ),
    );

    expect(find.text('20.05.2026'), findsOneWidget);
  });

  testWidgets('LearningEntryTile hides date in day and week modes',
      (tester) async {
    final entry = LearningEntry(
      id: '1',
      userId: 'user-1',
      date: DateTime(2026, 5, 20),
      startTime: DateTime.utc(2026, 5, 20, 8, 0),
      endTime: DateTime.utc(2026, 5, 20, 10, 0),
      breakMinutes: 10,
      topic: 'Flutter',
      createdAt: DateTime.utc(2026, 5, 20),
      updatedAt: DateTime.utc(2026, 5, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningEntryTile(entry: entry, showDate: false),
        ),
      ),
    );

    expect(find.text('20.05.2026'), findsNothing);
  });

  testWidgets('Learning timer start and stop basic flow', (tester) async {
    final bloc = _createBloc();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: LearningTimerCard(
              enableTicker: false,
              onStopOverride: () => bloc.add(
                const LearninglogTimerStopped(
                  userId: 'user-1',
                  topic: 'Timer topic',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Start'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });
}
