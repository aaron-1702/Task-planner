import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/remote/daily_goal_remote_store.dart';

part 'daily_goal_state.dart';

class DailyGoalCubit extends Cubit<DailyGoalState> {
  final DailyGoalRemoteStore _remoteStore;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final DateTime Function() _now;

  SharedPreferences? _prefs;
  StreamSubscription<void>? _remoteGoalsSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _isOnline = true;

  DailyGoalCubit(
    this._remoteStore, {
    Stream<List<ConnectivityResult>>? connectivityChanges,
    DateTime Function()? now,
  })  : _connectivityChanges =
            connectivityChanges ?? Connectivity().onConnectivityChanged,
        _now = now ?? DateTime.now,
        super(const DailyGoalState()) {
    _connectivitySub = _connectivityChanges.listen(_onConnectivityChanged);
  }

  Future<void> setUser(String userId) async {
    if (state.userId == userId && state.status == DailyGoalStatus.ready) {
      return;
    }

    await _remoteGoalsSub?.cancel();
    _pollTimer?.cancel();
    emit(state.copyWith(
      status: DailyGoalStatus.loading,
      userId: userId,
      clearError: true,
    ));

    final prefs = _prefs ??= await SharedPreferences.getInstance();
    emit(state.copyWith(
      templates: _loadTemplates(prefs, userId),
      completionsByDate: _loadCompletionsByDate(prefs, userId),
      updatedAtByKey: _loadUpdatedAtByKey(prefs, userId),
      status: DailyGoalStatus.ready,
    ));

    _remoteGoalsSub = _remoteStore.watchGoals(userId).listen((_) async {
      if (isClosed) return;
      await _flushPendingGoals(userId);
      if (isClosed) return;
      await _refreshGoalsFromServer(userId);
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (isClosed || !_isOnline || state.userId != userId) return;
      await _flushPendingGoals(userId);
      if (isClosed) return;
      await _refreshGoalsFromServer(userId, emitErrors: false);
    });

    await _flushPendingGoals(userId);
    await _refreshGoalsFromServer(userId, emitErrors: false);
  }

  Future<void> clearUser() async {
    await _remoteGoalsSub?.cancel();
    _pollTimer?.cancel();
    emit(const DailyGoalState());
  }

  Future<void> setGoals(List<String> titles) async {
    final userId = state.userId;
    if (userId == null) return;

    final normalizedTitles = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final nextTemplates = _reconcileTemplates(state.templates, normalizedTitles);
    final validIds = nextTemplates.map((template) => template.id).toSet();
    final nextCompletionsByDate = <String, Map<String, bool>>{};
    final nextUpdatedAtByKey = Map<String, DateTime>.from(state.updatedAtByKey);
    final nowUtc = _now().toUtc();

    for (final entry in state.completionsByDate.entries) {
      final filtered = Map<String, bool>.from(entry.value)
        ..removeWhere((goalId, isCompleted) =>
            !isCompleted || !validIds.contains(goalId));
      if (filtered.length != entry.value.length) {
        nextUpdatedAtByKey[_completionStorageKey(entry.key)] = nowUtc;
      }
      if (filtered.isNotEmpty) {
        nextCompletionsByDate[entry.key] = filtered;
      }
    }

    nextUpdatedAtByKey[DailyGoalRemoteStore.templatesStorageKey] = nowUtc;

    final nextSnapshot = DailyGoalSnapshot(
      templates: nextTemplates,
      completionsByDate: nextCompletionsByDate,
      updatedAtByKey: nextUpdatedAtByKey,
    );
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await _replaceLocalSnapshotCache(prefs, userId, nextSnapshot);

    emit(state.copyWith(
      templates: nextTemplates,
      completionsByDate: nextCompletionsByDate,
      updatedAtByKey: nextUpdatedAtByKey,
      clearError: true,
    ));

    await _storePendingSnapshot(userId, nextSnapshot);
    if (_isOnline) {
      await _pushSnapshotToServer(userId, nextSnapshot);
    }
  }

  Future<void> toggleGoalCompletion({
    required DateTime date,
    required String goalId,
    required bool isCompleted,
  }) async {
    final userId = state.userId;
    if (userId == null) return;
    if (!state.templates.any((template) => template.id == goalId)) return;

    final dateKey = _dateKey(date);
    final nextCompletionsByDate = <String, Map<String, bool>>{
      for (final entry in state.completionsByDate.entries)
        entry.key: Map<String, bool>.from(entry.value),
    };
    final nextCompletionsForDay =
        Map<String, bool>.from(nextCompletionsByDate[dateKey] ?? const {});

    if (isCompleted) {
      nextCompletionsForDay[goalId] = true;
      nextCompletionsByDate[dateKey] = nextCompletionsForDay;
    } else {
      nextCompletionsForDay.remove(goalId);
      if (nextCompletionsForDay.isEmpty) {
        nextCompletionsByDate.remove(dateKey);
      } else {
        nextCompletionsByDate[dateKey] = nextCompletionsForDay;
      }
    }

    final nextUpdatedAtByKey = Map<String, DateTime>.from(state.updatedAtByKey)
      ..[_completionStorageKey(dateKey)] = _now().toUtc();
    final nextSnapshot = DailyGoalSnapshot(
      templates: state.templates,
      completionsByDate: nextCompletionsByDate,
      updatedAtByKey: nextUpdatedAtByKey,
    );
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await _replaceLocalSnapshotCache(prefs, userId, nextSnapshot);

    emit(state.copyWith(
      completionsByDate: nextCompletionsByDate,
      updatedAtByKey: nextUpdatedAtByKey,
      clearError: true,
    ));

    await _storePendingSnapshot(userId, nextSnapshot);
    if (_isOnline) {
      await _pushSnapshotToServer(userId, nextSnapshot);
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = !results.contains(ConnectivityResult.none);

    if (!_isOnline && online && state.userId != null) {
      _isOnline = true;
      await _flushPendingGoals(state.userId!);
      await _refreshGoalsFromServer(state.userId!, emitErrors: false);
      return;
    }

    _isOnline = online;
  }

  Future<void> _pushSnapshotToServer(
    String userId,
    DailyGoalSnapshot localSnapshot,
  ) async {
    try {
      final mergedSnapshot =
          await _remoteStore.mergeAndSaveSnapshot(userId, localSnapshot);
      if (isClosed) return;
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await _replaceLocalSnapshotCache(prefs, userId, mergedSnapshot);
      if (isClosed) return;
      emit(state.copyWith(
        templates: mergedSnapshot.templates,
        completionsByDate: mergedSnapshot.completionsByDate,
        updatedAtByKey: mergedSnapshot.updatedAtByKey,
        clearError: true,
      ));
      await _clearPendingGoals(userId);
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _flushPendingGoals(String userId) async {
    final pendingSnapshot = await _loadPendingSnapshot(userId);
    if (pendingSnapshot == null) return;
    await _pushSnapshotToServer(userId, pendingSnapshot);
  }

  Future<void> _refreshGoalsFromServer(
    String userId, {
    bool emitErrors = true,
  }) async {
    try {
      final remoteSnapshot = await _remoteStore.fetchSnapshot(userId);
      if (isClosed) return;
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await _replaceLocalSnapshotCache(prefs, userId, remoteSnapshot);
      if (isClosed) return;
      emit(state.copyWith(
        templates: remoteSnapshot.templates,
        completionsByDate: remoteSnapshot.completionsByDate,
        updatedAtByKey: remoteSnapshot.updatedAtByKey,
        status: DailyGoalStatus.ready,
        clearError: true,
      ));
    } catch (error) {
      if (emitErrors) {
        if (isClosed) return;
        emit(state.copyWith(error: error.toString()));
      }
    }
  }

  Future<DailyGoalSnapshot?> _loadPendingSnapshot(String userId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPrefKey(userId));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return DailyGoalSnapshot(
        templates: _decodeTemplates(decoded['templates']),
        completionsByDate: _decodeCompletions(decoded['completions']),
        updatedAtByKey: _decodeUpdatedAt(decoded['updated_at']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _storePendingSnapshot(
    String userId,
    DailyGoalSnapshot snapshot,
  ) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final serialized = jsonEncode({
      'templates': snapshot.templates
          .map((template) => template.toJson())
          .toList(growable: false),
      'completions': snapshot.completionsByDate,
      'updated_at': snapshot.updatedAtByKey
          .map((key, value) => MapEntry(key, value.toUtc().toIso8601String())),
    });
    await prefs.setString(_pendingPrefKey(userId), serialized);
  }

  Future<void> _clearPendingGoals(String userId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(_pendingPrefKey(userId));
  }

  Future<void> _replaceLocalSnapshotCache(
    SharedPreferences prefs,
    String userId,
    DailyGoalSnapshot snapshot,
  ) async {
    final templatesKey = _templatesPrefKey(userId);
    final completionsPrefix = '${AppConstants.dailyGoalCompletionsKeyPrefix}:$userId:';
    final updatedAtPrefix = '${AppConstants.dailyGoalUpdatedAtKeyPrefix}:$userId:';

    await prefs.setString(
      templatesKey,
      jsonEncode(
        snapshot.templates
            .map((template) => template.toJson())
            .toList(growable: false),
      ),
    );

    for (final key in prefs.getKeys()) {
      if (key.startsWith(completionsPrefix) || key.startsWith(updatedAtPrefix)) {
        await prefs.remove(key);
      }
    }

    for (final entry in snapshot.completionsByDate.entries) {
      await prefs.setString(
        '$completionsPrefix${entry.key}',
        jsonEncode(entry.value),
      );
    }
    for (final entry in snapshot.updatedAtByKey.entries) {
      await prefs.setString(
        '$updatedAtPrefix${entry.key}',
        entry.value.toUtc().toIso8601String(),
      );
    }
  }

  List<DailyGoalTemplate> _loadTemplates(
    SharedPreferences prefs,
    String userId,
  ) {
    final raw = prefs.getString(_templatesPrefKey(userId));
    if (raw == null) return const [];

    try {
      return _decodeTemplates(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  Map<String, Map<String, bool>> _loadCompletionsByDate(
    SharedPreferences prefs,
    String userId,
  ) {
    final prefix = '${AppConstants.dailyGoalCompletionsKeyPrefix}:$userId:';
    final result = <String, Map<String, bool>>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final dateKey = key.substring(prefix.length);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        final completions = _decodeSingleDateCompletionMap(decoded);
        if (completions.isNotEmpty) {
          result[dateKey] = completions;
        }
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  Map<String, DateTime> _loadUpdatedAtByKey(
    SharedPreferences prefs,
    String userId,
  ) {
    final prefix = '${AppConstants.dailyGoalUpdatedAtKeyPrefix}:$userId:';
    final result = <String, DateTime>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final storageKey = key.substring(prefix.length);
      final rawIso = prefs.getString(key);
      final parsed = rawIso != null ? DateTime.tryParse(rawIso)?.toUtc() : null;
      if (parsed == null) continue;
      result[storageKey] = parsed;
    }

    return result;
  }

  List<DailyGoalTemplate> _reconcileTemplates(
    List<DailyGoalTemplate> existing,
    List<String> titles,
  ) {
    final poolByNormalizedTitle = <String, List<DailyGoalTemplate>>{};
    for (final template in existing) {
      final key = template.title.toLowerCase();
      poolByNormalizedTitle.putIfAbsent(key, () => []).add(template);
    }

    final result = <DailyGoalTemplate>[];
    for (var index = 0; index < titles.length; index++) {
      final title = titles[index];
      final key = title.toLowerCase();
      final pool = poolByNormalizedTitle[key];
      if (pool != null && pool.isNotEmpty) {
        result.add(pool.removeAt(0).copyWith(title: title));
        continue;
      }

      result.add(
        DailyGoalTemplate(
          id: '${_now().toUtc().microsecondsSinceEpoch}_$index',
          title: title,
        ),
      );
    }

    return result;
  }

  List<DailyGoalTemplate> _decodeTemplates(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(DailyGoalTemplate.fromJson)
        .whereType<DailyGoalTemplate>()
        .toList(growable: false);
  }

  Map<String, Map<String, bool>> _decodeCompletions(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, Map<String, bool>>{};
    for (final entry in raw.entries) {
      final completions = _decodeSingleDateCompletionMap(entry.value);
      if (completions.isNotEmpty) {
        result[entry.key.toString()] = completions;
      }
    }
    return result;
  }

  Map<String, bool> _decodeSingleDateCompletionMap(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, bool>{};
    for (final entry in raw.entries) {
      if (entry.value == true) {
        result[entry.key.toString()] = true;
      }
    }
    return result;
  }

  Map<String, DateTime> _decodeUpdatedAt(dynamic raw) {
    if (raw is! Map) return const {};

    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value.toString())?.toUtc();
      if (parsed == null) continue;
      result[entry.key.toString()] = parsed;
    }
    return result;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _completionStorageKey(String dateKey) {
    return '${DailyGoalRemoteStore.completionKeyPrefix}$dateKey';
  }

  static String _templatesPrefKey(String userId) {
    return '${AppConstants.dailyGoalTemplatesKeyPrefix}:$userId';
  }

  static String _pendingPrefKey(String userId) {
    return '${AppConstants.dailyGoalPendingKeyPrefix}:$userId';
  }

  @override
  Future<void> close() async {
    await _remoteGoalsSub?.cancel();
    await _connectivitySub?.cancel();
    _pollTimer?.cancel();
    await super.close();
  }
}