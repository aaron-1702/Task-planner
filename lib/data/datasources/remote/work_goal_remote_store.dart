import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

class WorkGoalSnapshot {
  final Map<String, int> goals;
  final Map<String, DateTime> updatedAtByMonth;

  const WorkGoalSnapshot({
    this.goals = const {},
    this.updatedAtByMonth = const {},
  });
}

abstract class WorkGoalRemoteStore {
  Future<WorkGoalSnapshot> fetchSnapshot(String userId);
  Future<WorkGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    WorkGoalSnapshot localSnapshot,
  );
  Stream<void> watchGoals(String userId);
}

class SupabaseWorkGoalRemoteStore implements WorkGoalRemoteStore {
  final SupabaseClient _client;

  const SupabaseWorkGoalRemoteStore(this._client);

  @override
  Future<WorkGoalSnapshot> fetchSnapshot(String userId) async {
    final response = await _client
        .from(AppConstants.usersTable)
        .select('work_goal_minutes, work_goal_updated_at')
        .eq('id', userId)
        .maybeSingle();

    return WorkGoalSnapshot(
      goals: _parseIntMap(response?['work_goal_minutes']),
      updatedAtByMonth: _parseDateMap(response?['work_goal_updated_at']),
    );
  }

  @override
  Future<WorkGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    WorkGoalSnapshot localSnapshot,
  ) async {
    final remoteSnapshot = await fetchSnapshot(userId);
    final mergedSnapshot = _mergeSnapshots(remoteSnapshot, localSnapshot);

    await _client.from(AppConstants.usersTable).upsert({
      'id': userId,
      'work_goal_minutes': _encodeIntMap(mergedSnapshot.goals),
      'work_goal_updated_at': _encodeDateMap(mergedSnapshot.updatedAtByMonth),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return mergedSnapshot;
  }

  @override
  Stream<void> watchGoals(String userId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;

    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client
            .channel('${AppConstants.userProfilesChannel}:work:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: AppConstants.usersTable,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: userId,
              ),
              callback: (_) {
                if (!controller.isClosed) {
                  controller.add(null);
                }
              },
            )
            .subscribe();
      },
      onCancel: () async {
        await channel?.unsubscribe();
      },
    );

    return controller.stream;
  }

  static WorkGoalSnapshot _mergeSnapshots(
    WorkGoalSnapshot remote,
    WorkGoalSnapshot local,
  ) {
    final mergedGoals = <String, int>{};
    final mergedUpdatedAt = <String, DateTime>{};
    final allKeys = <String>{
      ...remote.goals.keys,
      ...local.goals.keys,
      ...remote.updatedAtByMonth.keys,
      ...local.updatedAtByMonth.keys,
    };

    for (final key in allKeys) {
      final remoteUpdatedAt = remote.updatedAtByMonth[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localUpdatedAt = local.updatedAtByMonth[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins = localUpdatedAt.isAfter(remoteUpdatedAt) ||
          localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt);

      if (localWins) {
        final localMinutes = local.goals[key] ?? 0;
        if (localMinutes > 0) {
          mergedGoals[key] = localMinutes;
        }
        mergedUpdatedAt[key] = localUpdatedAt;
      } else {
        final remoteMinutes = remote.goals[key] ?? 0;
        if (remoteMinutes > 0) {
          mergedGoals[key] = remoteMinutes;
        }
        mergedUpdatedAt[key] = remoteUpdatedAt;
      }
    }

    return WorkGoalSnapshot(
      goals: mergedGoals,
      updatedAtByMonth: mergedUpdatedAt,
    );
  }

  static Map<String, int> _parseIntMap(dynamic raw) {
    if (raw is! Map) return const {};

    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
      ),
    )..removeWhere((_, value) => value <= 0);
  }

  static Map<String, DateTime> _parseDateMap(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value.toString())?.toUtc();
      if (parsed == null) continue;
      result[entry.key.toString()] = parsed;
    }
    return result;
  }

  static Map<String, int> _encodeIntMap(Map<String, int> source) {
    return Map<String, int>.from(source)..removeWhere((_, value) => value <= 0);
  }

  static Map<String, String> _encodeDateMap(Map<String, DateTime> source) {
    return source.map(
      (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
    );
  }
}
