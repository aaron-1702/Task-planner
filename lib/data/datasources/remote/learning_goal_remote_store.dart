import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

class LearningGoalSnapshot {
  final Map<String, int> goals;
  final Map<String, DateTime> updatedAtByMonth;

  const LearningGoalSnapshot({
    this.goals = const {},
    this.updatedAtByMonth = const {},
  });
}

abstract class LearningGoalRemoteStore {
  Future<LearningGoalSnapshot> fetchSnapshot(String userId);
  Future<LearningGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    LearningGoalSnapshot localSnapshot,
  );
  Stream<void> watchGoals(String userId);
}

class SupabaseLearningGoalRemoteStore implements LearningGoalRemoteStore {
  final SupabaseClient _client;

  const SupabaseLearningGoalRemoteStore(this._client);

  @override
  Future<LearningGoalSnapshot> fetchSnapshot(String userId) async {
    final response = await _client
        .from(AppConstants.usersTable)
        .select('learning_goal_minutes, learning_goal_updated_at')
        .eq('id', userId)
        .maybeSingle();

    final goals = _parseIntMap(response?['learning_goal_minutes']);
    final updatedAtByMonth = _parseDateMap(response?['learning_goal_updated_at']);

    return LearningGoalSnapshot(
      goals: goals,
      updatedAtByMonth: updatedAtByMonth,
    );
  }

  @override
  Future<LearningGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    LearningGoalSnapshot localSnapshot,
  ) async {
    final remoteSnapshot = await fetchSnapshot(userId);
    final mergedSnapshot = _mergeSnapshots(remoteSnapshot, localSnapshot);
    final currentEmail = _client.auth.currentUser?.email;

    await _client.from(AppConstants.usersTable).upsert({
      'id': userId,
      if (currentEmail != null && currentEmail.isNotEmpty) 'email': currentEmail,
      'learning_goal_minutes': _encodeIntMap(mergedSnapshot.goals),
      'learning_goal_updated_at': _encodeDateMap(mergedSnapshot.updatedAtByMonth),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return mergedSnapshot;
  }

  static LearningGoalSnapshot _mergeSnapshots(
    LearningGoalSnapshot remote,
    LearningGoalSnapshot local,
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
      final remoteUpdatedAt = remote.updatedAtByMonth[key] ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localUpdatedAt = local.updatedAtByMonth[key] ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins =
          localUpdatedAt.isAfter(remoteUpdatedAt) || localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt);

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

    return LearningGoalSnapshot(
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
    return Map<String, int>.from(source)
      ..removeWhere((_, value) => value <= 0);
  }

  static Map<String, String> _encodeDateMap(Map<String, DateTime> source) {
    return source.map(
      (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
    );
  }

  @override
  Stream<void> watchGoals(String userId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;

    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client
            .channel('${AppConstants.userProfilesChannel}:$userId')
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
}
