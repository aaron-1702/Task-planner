import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_task_planner/core/errors/failures.dart';
import 'package:smart_task_planner/data/datasources/remote/work_goal_remote_store.dart';
import 'package:smart_task_planner/domain/entities/work_entry.dart';
import 'package:smart_task_planner/domain/repositories/work_entry_repository.dart';
import 'package:smart_task_planner/domain/usecases/work_entry_usecases.dart';
import 'package:smart_task_planner/presentation/blocs/work_goal/work_goal_cubit.dart';

class _FakeWorkEntryRepository implements WorkEntryRepository {
  final _controller = StreamController<List<WorkEntry>>.broadcast();
  final List<WorkEntry> _entries = [];

  _FakeWorkEntryRepository(List<WorkEntry> seed) {
    _entries.addAll(seed);
    _controller.add(List<WorkEntry>.from(_entries));
  }

  @override
  Future<Either<Failure, WorkEntry>> createEntry(WorkEntry entry) async {
    _entries.add(entry);
    _controller.add(List<WorkEntry>.from(_entries));
    return Right(entry);
  }

  @override
  Future<Either<Failure, Unit>> deleteEntry(String entryId, String userId) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> syncFromRemote(String userId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, WorkEntry>> updateEntry(WorkEntry entry) async {
    return Right(entry);
  }

  @override
  Stream<List<WorkEntry>> watchEntriesByUser(String userId) {
    return () async* {
      yield _entries.where((entry) => entry.userId == userId).toList();
      yield* _controller.stream
          .map((entries) => entries.where((entry) => entry.userId == userId).toList());
    }();
  }

  @override
  Stream<List<WorkEntry>> watchEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  void dispose() {
    _controller.close();
  }
}

class _FakeWorkGoalRemoteStore implements WorkGoalRemoteStore {
  final _controller = StreamController<void>.broadcast();
  WorkGoalSnapshot snapshot = const WorkGoalSnapshot();

  @override
  Future<WorkGoalSnapshot> fetchSnapshot(String userId) async {
    return WorkGoalSnapshot(
      goals: Map<String, int>.from(snapshot.goals),
      updatedAtByMonth: Map<String, DateTime>.from(snapshot.updatedAtByMonth),
    );
  }

  @override
  Future<WorkGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    WorkGoalSnapshot localSnapshot,
  ) async {
    final mergedGoals = <String, int>{};
    final mergedUpdatedAt = <String, DateTime>{};
    final allKeys = <String>{
      ...snapshot.goals.keys,
      ...localSnapshot.goals.keys,
      ...snapshot.updatedAtByMonth.keys,
      ...localSnapshot.updatedAtByMonth.keys,
    };

    for (final key in allKeys) {
      final remoteTs =
          snapshot.updatedAtByMonth[key] ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localTs = localSnapshot.updatedAtByMonth[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins = localTs.isAfter(remoteTs) || localTs.isAtSameMomentAs(remoteTs);

      if (localWins) {
        final value = localSnapshot.goals[key] ?? 0;
        if (value > 0) {
          mergedGoals[key] = value;
        }
        mergedUpdatedAt[key] = localTs;
      } else {
        final value = snapshot.goals[key] ?? 0;
        if (value > 0) {
          mergedGoals[key] = value;
        }
        mergedUpdatedAt[key] = remoteTs;
      }
    }

    snapshot = WorkGoalSnapshot(
      goals: mergedGoals,
      updatedAtByMonth: mergedUpdatedAt,
    );
    _controller.add(null);
    return snapshot;
  }

  @override
  Stream<void> watchGoals(String userId) => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

WorkEntry _entry({
  required String id,
  required DateTime date,
  required int startHour,
  required int endHour,
}) {
  return WorkEntry(
    id: id,
    userId: 'user-1',
    date: DateTime(date.year, date.month, date.day),
    startTime: DateTime.utc(date.year, date.month, date.day, startHour),
    endTime: DateTime.utc(date.year, date.month, date.day, endHour),
    createdAt: DateTime.utc(date.year, date.month, date.day),
    updatedAt: DateTime.utc(date.year, date.month, date.day),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores monthly work goal and calculates progress from entries', () async {
    final repo = _FakeWorkEntryRepository([
      _entry(id: 'a', date: DateTime(2026, 5, 3), startHour: 8, endHour: 10),
      _entry(id: 'b', date: DateTime(2026, 5, 8), startHour: 12, endHour: 13),
      _entry(id: 'c', date: DateTime(2026, 6, 2), startHour: 9, endHour: 11),
    ]);
    final remoteStore = _FakeWorkGoalRemoteStore();
    final cubit = WorkGoalCubit(
      WatchWorkEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    final month = DateTime(2026, 5, 1);

    await cubit.setUser('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await cubit.setGoalForMonth(month, const Duration(hours: 5));

    expect(cubit.state.goalForMonth(month), const Duration(hours: 5));
    expect(cubit.state.workedForMonth(month), const Duration(hours: 3));
    expect(cubit.state.remainingForMonth(month), const Duration(hours: 2));
    expect(cubit.state.progressForMonth(month), 0.6);
    expect(remoteStore.snapshot.goals['2026-05'], 300);

    await cubit.close();
    repo.dispose();
    remoteStore.dispose();
  });
}
