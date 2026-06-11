import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

class DailyGoalTemplate {
  final String id;
  final String title;

  const DailyGoalTemplate({
    required this.id,
    required this.title,
  });

  DailyGoalTemplate copyWith({
    String? id,
    String? title,
  }) {
    return DailyGoalTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
    );
  }

  Map<String, String> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }

  static DailyGoalTemplate? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    final id = raw['id']?.toString().trim() ?? '';
    final title = raw['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    return DailyGoalTemplate(id: id, title: title);
  }
}

class DailyGoalSnapshot {
  final List<DailyGoalTemplate> templates;
  final Map<String, Map<String, bool>> completionsByDate;
  final Map<String, DateTime> updatedAtByKey;

  const DailyGoalSnapshot({
    this.templates = const [],
    this.completionsByDate = const {},
    this.updatedAtByKey = const {},
  });
}

abstract class DailyGoalRemoteStore {
  static const String templatesStorageKey = 'templates';
  static const String completionKeyPrefix = 'completion:';

  Future<DailyGoalSnapshot> fetchSnapshot(String userId);
  Future<DailyGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    DailyGoalSnapshot localSnapshot,
  );
  Stream<void> watchGoals(String userId);
}

class SupabaseDailyGoalRemoteStore implements DailyGoalRemoteStore {
  final SupabaseClient _client;

  const SupabaseDailyGoalRemoteStore(this._client);

  @override
  Future<DailyGoalSnapshot> fetchSnapshot(String userId) async {
    final response = await _client
        .from(AppConstants.usersTable)
        .select(
          'daily_goal_templates, daily_goal_completions, daily_goal_updated_at',
        )
        .eq('id', userId)
        .maybeSingle();

    return DailyGoalSnapshot(
      templates: _parseTemplates(response?['daily_goal_templates']),
      completionsByDate: _parseCompletions(response?['daily_goal_completions']),
      updatedAtByKey: _parseDateMap(response?['daily_goal_updated_at']),
    );
  }

  @override
  Future<DailyGoalSnapshot> mergeAndSaveSnapshot(
    String userId,
    DailyGoalSnapshot localSnapshot,
  ) async {
    final remoteSnapshot = await fetchSnapshot(userId);
    final mergedSnapshot = _mergeSnapshots(remoteSnapshot, localSnapshot);
    final currentUser = _client.auth.currentUser;
    final currentEmail = currentUser?.email ??
        currentUser?.userMetadata?['email']?.toString() ??
        '';
    final payload = {
      'daily_goal_templates': _encodeTemplates(mergedSnapshot.templates),
      'daily_goal_completions': _encodeCompletions(
        mergedSnapshot.completionsByDate,
      ),
      'daily_goal_updated_at': _encodeDateMap(mergedSnapshot.updatedAtByKey),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final updatedRow = await _client
        .from(AppConstants.usersTable)
        .update(payload)
        .eq('id', userId)
        .select('id')
        .maybeSingle();

    if (updatedRow == null) {
      await _client.from(AppConstants.usersTable).upsert({
        'id': userId,
        'email': currentEmail,
        ...payload,
      }, onConflict: 'id');
    }

    return mergedSnapshot;
  }

  @override
  Stream<void> watchGoals(String userId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;

    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client
            .channel('${AppConstants.userProfilesChannel}:daily:$userId')
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

  static DailyGoalSnapshot _mergeSnapshots(
    DailyGoalSnapshot remote,
    DailyGoalSnapshot local,
  ) {
    final mergedTemplates = <DailyGoalTemplate>[];
    final mergedCompletionsByDate = <String, Map<String, bool>>{};
    final mergedUpdatedAtByKey = <String, DateTime>{};
    final allKeys = <String>{
      ...remote.updatedAtByKey.keys,
      ...local.updatedAtByKey.keys,
      if (remote.templates.isNotEmpty || local.templates.isNotEmpty)
        DailyGoalRemoteStore.templatesStorageKey,
      ...remote.completionsByDate.keys.map(_completionStorageKey),
      ...local.completionsByDate.keys.map(_completionStorageKey),
    };

    for (final key in allKeys) {
      final remoteUpdatedAt = remote.updatedAtByKey[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localUpdatedAt = local.updatedAtByKey[key] ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final localWins = localUpdatedAt.isAfter(remoteUpdatedAt) ||
          localUpdatedAt.isAtSameMomentAs(remoteUpdatedAt);

      if (key == DailyGoalRemoteStore.templatesStorageKey) {
        final source = localWins ? local.templates : remote.templates;
        mergedTemplates
          ..clear()
          ..addAll(source.map((template) => template.copyWith()));
      } else if (key.startsWith(DailyGoalRemoteStore.completionKeyPrefix)) {
        final dateKey = key.substring(DailyGoalRemoteStore.completionKeyPrefix.length);
        final source = localWins
            ? local.completionsByDate[dateKey]
            : remote.completionsByDate[dateKey];
        if (source != null && source.isNotEmpty) {
          mergedCompletionsByDate[dateKey] = Map<String, bool>.from(source)
            ..removeWhere((_, value) => !value);
        }
      }

      mergedUpdatedAtByKey[key] = localWins ? localUpdatedAt : remoteUpdatedAt;
    }

    return DailyGoalSnapshot(
      templates: mergedTemplates,
      completionsByDate: mergedCompletionsByDate,
      updatedAtByKey: mergedUpdatedAtByKey,
    );
  }

  static List<DailyGoalTemplate> _parseTemplates(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .map(DailyGoalTemplate.fromJson)
        .whereType<DailyGoalTemplate>()
        .toList(growable: false);
  }

  static Map<String, Map<String, bool>> _parseCompletions(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, Map<String, bool>>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final dateKey = entry.key.toString();
      final dateCompletions = <String, bool>{};
      for (final completionEntry in (entry.value as Map).entries) {
        final isCompleted = completionEntry.value == true;
        if (!isCompleted) continue;
        dateCompletions[completionEntry.key.toString()] = true;
      }
      if (dateCompletions.isNotEmpty) {
        result[dateKey] = dateCompletions;
      }
    }
    return result;
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

  static List<Map<String, String>> _encodeTemplates(
    List<DailyGoalTemplate> templates,
  ) {
    return templates.map((template) => template.toJson()).toList(growable: false);
  }

  static Map<String, Map<String, bool>> _encodeCompletions(
    Map<String, Map<String, bool>> source,
  ) {
    final result = <String, Map<String, bool>>{};

    for (final entry in source.entries) {
      final completedGoals = Map<String, bool>.from(entry.value)
        ..removeWhere((_, value) => !value);
      if (completedGoals.isEmpty) continue;
      result[entry.key] = completedGoals;
    }

    return result;
  }

  static Map<String, String> _encodeDateMap(Map<String, DateTime> source) {
    return source.map(
      (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
    );
  }

  static String _completionStorageKey(String dateKey) {
    return '${DailyGoalRemoteStore.completionKeyPrefix}$dateKey';
  }
}