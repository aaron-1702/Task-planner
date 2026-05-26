import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:smart_task_planner/core/errors/failures.dart';
import 'package:smart_task_planner/domain/entities/learning_entry.dart';
import 'package:smart_task_planner/domain/repositories/learning_entry_repository.dart';
import 'package:smart_task_planner/domain/usecases/learning_entry_usecases.dart';
import 'package:smart_task_planner/presentation/blocs/learninglog/learninglog_bloc.dart';

class _FakeLearningEntryRepository implements LearningEntryRepository {
  final _controller = StreamController<List<LearningEntry>>.broadcast();
  final List<LearningEntry> _entries = [];

  _FakeLearningEntryRepository(List<LearningEntry> seed) {
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

LearninglogBloc _createBloc(_FakeLearningEntryRepository repo) {
  return LearninglogBloc(
    WatchLearningEntriesUseCase(repo),
    CreateLearningEntryUseCase(repo),
    UpdateLearningEntryUseCase(repo),
    DeleteLearningEntryUseCase(repo),
    SyncLearningEntriesUseCase(repo),
    const ExportLearningEntriesCsvUseCase(),
  );
}

LearningEntry _entry({
  required String id,
  required DateTime date,
}) {
  return LearningEntry(
    id: id,
    userId: 'user-1',
    date: DateTime(date.year, date.month, date.day),
    startTime: DateTime.utc(date.year, date.month, date.day, 8, 0),
    endTime: DateTime.utc(date.year, date.month, date.day, 10, 0),
    breakMinutes: 10,
    topic: 'Topic $id',
    createdAt: DateTime.utc(date.year, date.month, date.day),
    updatedAt: DateTime.utc(date.year, date.month, date.day),
  );
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'de_DE';
    await initializeDateFormatting('de_DE');
  });

  test('periodEntries filters by selected week', () async {
    final repo = _FakeLearningEntryRepository([
      _entry(id: 'a', date: DateTime(2026, 5, 19)),
      _entry(id: 'b', date: DateTime(2026, 5, 21)),
      _entry(id: 'c', date: DateTime(2026, 6, 1)),
    ]);

    final bloc = _createBloc(repo);

    bloc.add(const LearninglogSubscriptionRequested('user-1'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    bloc.add(const LearninglogViewModeChanged(LearninglogViewMode.week));
    bloc.add(LearninglogDateChanged(DateTime(2026, 5, 20)));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final ids = bloc.state.periodEntries.map((e) => e.id).toSet();

    expect(ids.contains('a'), isTrue);
    expect(ids.contains('b'), isTrue);
    expect(ids.contains('c'), isFalse);

    await bloc.close();
    repo.dispose();
  });
}
