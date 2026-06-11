import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_task_planner/data/datasources/remote/daily_goal_remote_store.dart';
import 'package:smart_task_planner/presentation/blocs/daily_goal/daily_goal_cubit.dart';

class _FakeDailyGoalRemoteStore implements DailyGoalRemoteStore {
  final _controller = StreamController<void>.broadcast();
  DailyGoalSnapshot snapshot = const DailyGoalSnapshot();

  @override
  Future<DailyGoalSnapshot> fetchSnapshot(String userId) async {
    return DailyGoalSnapshot(
      templates: snapshot.templates
          .map((template) => template.copyWith())
          .toList(growable: false),
      completionsByDate: snapshot.completionsByDate.map(
        (key, value) => MapEntry(key, Map<String, bool>.from(value)),
      ),
      updatedAtByKey: Map<String, DateTime>.from(snapshot.updatedAtByKey),
    );
  }

  @override
  Future<DailyGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    DailyGoalSnapshot localSnapshot,
  ) async {
    final mergedTemplates = <DailyGoalTemplate>[];
    final mergedCompletionsByDate = <String, Map<String, bool>>{};
    final mergedUpdatedAtByKey = <String, DateTime>{};
    final allKeys = <String>{
      ...snapshot.updatedAtByKey.keys,
      ...localSnapshot.updatedAtByKey.keys,
    };

    for (final key in allKeys) {
      final remoteUpdatedAt = snapshot.updatedAtByKey[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localUpdatedAt = localSnapshot.updatedAtByKey[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins = localUpdatedAt.isAfter(remoteUpdatedAt) ||
          localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt);

      if (key == DailyGoalRemoteStore.templatesStorageKey) {
        final source = localWins ? localSnapshot.templates : snapshot.templates;
        mergedTemplates
          ..clear()
          ..addAll(source.map((template) => template.copyWith()));
      } else if (key.startsWith(DailyGoalRemoteStore.completionKeyPrefix)) {
        final source = localWins
            ? localSnapshot.completionsByDate[key.substring(
                DailyGoalRemoteStore.completionKeyPrefix.length,
              )]
            : snapshot.completionsByDate[key.substring(
                DailyGoalRemoteStore.completionKeyPrefix.length,
              )];
        if (source != null && source.isNotEmpty) {
          mergedCompletionsByDate[key.substring(
            DailyGoalRemoteStore.completionKeyPrefix.length,
          )] = Map<String, bool>.from(source);
        }
      }

      mergedUpdatedAtByKey[key] = localWins ? localUpdatedAt : remoteUpdatedAt;
    }

    snapshot = DailyGoalSnapshot(
      templates: mergedTemplates,
      completionsByDate: mergedCompletionsByDate,
      updatedAtByKey: mergedUpdatedAtByKey,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daily goals repeat on a new day while completion resets per date', () async {
    var currentDate = DateTime(2026, 6, 11, 8);
    final remoteStore = _FakeDailyGoalRemoteStore();
    final cubit = DailyGoalCubit(
      remoteStore,
      now: () => currentDate,
      connectivityChanges: const Stream.empty(),
    );

    await cubit.setUser('user-1');
    await cubit.setGoals(const ['Inbox aufraeumen', 'Workout', 'Lesen']);

    expect(
      cubit.state.goalsForDate(currentDate).map((goal) => goal.title).toList(),
      const ['Inbox aufraeumen', 'Workout', 'Lesen'],
    );
    expect(cubit.state.completedCountForDate(currentDate), 0);

    await cubit.toggleGoalCompletion(
      date: currentDate,
      goalId: cubit.state.goalsForDate(currentDate).first.id,
      isCompleted: true,
    );

    expect(cubit.state.completedCountForDate(currentDate), 1);
    expect(cubit.state.progressForDate(currentDate), closeTo(1 / 3, 0.001));

    currentDate = DateTime(2026, 6, 12, 8);
    expect(
      cubit.state.goalsForDate(currentDate).every((goal) => !goal.isCompleted),
      isTrue,
    );
    expect(cubit.state.completedCountForDate(currentDate), 0);

    await cubit.close();
    remoteStore.dispose();
  });

  test('reloads templates and same-day completion state from remote sync', () async {
    final remoteStore = _FakeDailyGoalRemoteStore();
    final currentDate = DateTime(2026, 6, 11, 8);

    final firstCubit = DailyGoalCubit(
      remoteStore,
      now: () => currentDate,
      connectivityChanges: const Stream.empty(),
    );
    await firstCubit.setUser('user-1');
    await firstCubit.setGoals(const ['Planen', 'Lernen']);
    await firstCubit.toggleGoalCompletion(
      date: currentDate,
      goalId: firstCubit.state.goalsForDate(currentDate).last.id,
      isCompleted: true,
    );
    await firstCubit.close();

    final secondCubit = DailyGoalCubit(
      remoteStore,
      now: () => currentDate,
      connectivityChanges: const Stream.empty(),
    );
    await secondCubit.setUser('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final goals = secondCubit.state.goalsForDate(currentDate);
    expect(goals.map((goal) => goal.title).toList(), const ['Planen', 'Lernen']);
    expect(goals.last.isCompleted, isTrue);

    await secondCubit.close();
    remoteStore.dispose();
  });
}