import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_task_planner/core/errors/failures.dart';
import 'package:smart_task_planner/data/datasources/remote/learning_goal_remote_store.dart';
import 'package:smart_task_planner/domain/entities/learning_entry.dart';
import 'package:smart_task_planner/domain/repositories/learning_entry_repository.dart';
import 'package:smart_task_planner/domain/usecases/learning_entry_usecases.dart';
import 'package:smart_task_planner/presentation/blocs/learning_goal/learning_goal_cubit.dart';

class _FakeLearningEntryRepository implements LearningEntryRepository {
  final _controller = StreamController<List<LearningEntry>>.broadcast();
  final List<LearningEntry> _entries = [];

  _FakeLearningEntryRepository(List<LearningEntry> seed) {
    _entries.addAll(seed);
    _controller.add(List<LearningEntry>.from(_entries));
  }

  @override
  Future<Either<Failure, LearningEntry>> createEntry(
    LearningEntry entry,
  ) async {
    _entries.add(entry);
    _controller.add(List<LearningEntry>.from(_entries));
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
  Future<Either<Failure, LearningEntry>> updateEntry(
    LearningEntry entry,
  ) async {
    return Right(entry);
  }

  @override
  Stream<List<LearningEntry>> watchEntriesByUser(String userId) {
    return () async* {
      yield _entries.where((entry) => entry.userId == userId).toList();
      yield* _controller.stream.map(
        (entries) => entries.where((entry) => entry.userId == userId).toList(),
      );
    }();
  }

  @override
  Stream<List<LearningEntry>> watchEntriesInRange(
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

class _FakeLearningGoalRemoteStore implements LearningGoalRemoteStore {
  final _controller = StreamController<void>.broadcast();
  LearningGoalSnapshot snapshot = const LearningGoalSnapshot();

  @override
  Future<LearningGoalSnapshot> fetchSnapshot(String userId) async {
    return LearningGoalSnapshot(
      goals: Map<String, int>.from(snapshot.goals),
      updatedAtByMonth: Map<String, DateTime>.from(snapshot.updatedAtByMonth),
    );
  }

  @override
  Future<LearningGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    LearningGoalSnapshot localSnapshot,
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
      final remoteTs = snapshot.updatedAtByMonth[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localTs = localSnapshot.updatedAtByMonth[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins =
          localTs.isAfter(remoteTs) || localTs.isAtSameMomentAs(remoteTs);

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

    snapshot = LearningGoalSnapshot(
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

LearningEntry _entry({
  required String id,
  required DateTime date,
  required int startHour,
  required int endHour,
}) {
  return LearningEntry(
    id: id,
    userId: 'user-1',
    date: DateTime(date.year, date.month, date.day),
    startTime: DateTime.utc(date.year, date.month, date.day, startHour),
    endTime: DateTime.utc(date.year, date.month, date.day, endHour),
    topic: 'Topic $id',
    createdAt: DateTime.utc(date.year, date.month, date.day),
    updatedAt: DateTime.utc(date.year, date.month, date.day),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores monthly goal and calculates progress from entries', () async {
    final repo = _FakeLearningEntryRepository([
      _entry(id: 'a', date: DateTime(2026, 5, 3), startHour: 8, endHour: 10),
      _entry(id: 'b', date: DateTime(2026, 5, 8), startHour: 12, endHour: 13),
      _entry(id: 'c', date: DateTime(2026, 6, 2), startHour: 9, endHour: 11),
    ]);
    final remoteStore = _FakeLearningGoalRemoteStore();
    final cubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    final month = DateTime(2026, 5, 1);

    await cubit.setUser('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await cubit.setGoalForMonth(month, const Duration(hours: 5));

    expect(cubit.state.goalForMonth(month), const Duration(hours: 5));
    expect(cubit.state.learnedForMonth(month), const Duration(hours: 3));
    expect(cubit.state.remainingForMonth(month), const Duration(hours: 2));
    expect(cubit.state.progressForMonth(month), 0.6);
    expect(remoteStore.snapshot.goals['2026-05'], 300);

    await cubit.close();
    repo.dispose();
    remoteStore.dispose();
  });

  test('reloads stored monthly goal from remote sync', () async {
    final repo = _FakeLearningEntryRepository(const []);
    final remoteStore = _FakeLearningGoalRemoteStore();
    final month = DateTime(2026, 7, 1);

    final firstCubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    await firstCubit.setUser('user-1');
    await firstCubit.setGoalForMonth(month, const Duration(hours: 12));
    await firstCubit.close();

    final secondCubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    await secondCubit.setUser('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(secondCubit.state.goalForMonth(month), const Duration(hours: 12));

    await secondCubit.close();
    repo.dispose();
    remoteStore.dispose();
  });

  test('receives realtime goal updates from another device session', () async {
    final repo = _FakeLearningEntryRepository(const []);
    final remoteStore = _FakeLearningGoalRemoteStore();
    final firstCubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    final secondCubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );
    final month = DateTime(2026, 8, 1);

    await firstCubit.setUser('user-1');
    await secondCubit.setUser('user-1');
    await firstCubit.setGoalForMonth(month, const Duration(hours: 9));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(secondCubit.state.goalForMonth(month), const Duration(hours: 9));

    await firstCubit.close();
    await secondCubit.close();
    repo.dispose();
    remoteStore.dispose();
  });

  test('keeps newer remote month value when local update is older', () async {
    final repo = _FakeLearningEntryRepository(const []);
    final remoteStore = _FakeLearningGoalRemoteStore()
      ..snapshot = LearningGoalSnapshot(
        goals: const {'2026-09': 480},
        updatedAtByMonth: {
          '2026-09': DateTime.utc(2099, 1, 1),
        },
      );
    final cubit = LearningGoalCubit(
      WatchLearningEntriesUseCase(repo),
      remoteStore,
      connectivityChanges: const Stream.empty(),
    );

    await cubit.setUser('user-1');
    await cubit.setGoalForMonth(DateTime(2026, 9, 1), const Duration(hours: 4));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.goalForMonth(DateTime(2026, 9, 1)), const Duration(hours: 8));

    await cubit.close();
    repo.dispose();
    remoteStore.dispose();
  });
}