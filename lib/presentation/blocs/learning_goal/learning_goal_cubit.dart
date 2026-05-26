import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/remote/learning_goal_remote_store.dart';
import '../../../domain/entities/learning_entry.dart';
import '../../../domain/usecases/learning_entry_usecases.dart';

part 'learning_goal_state.dart';

class LearningGoalCubit extends Cubit<LearningGoalState> {
  final WatchLearningEntriesUseCase _watchEntries;
  final LearningGoalRemoteStore _remoteStore;
  final Stream<List<ConnectivityResult>> _connectivityChanges;

  SharedPreferences? _prefs;
  StreamSubscription<List<LearningEntry>>? _entriesSub;
  StreamSubscription<void>? _remoteGoalsSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  LearningGoalCubit(
    this._watchEntries,
    this._remoteStore, {
    Stream<List<ConnectivityResult>>? connectivityChanges,
  })  : _connectivityChanges =
            connectivityChanges ?? Connectivity().onConnectivityChanged,
        super(const LearningGoalState()) {
    _connectivitySub = _connectivityChanges.listen(_onConnectivityChanged);
  }

  Future<void> setUser(String userId) async {
    if (state.userId == userId && state.status == LearningGoalStatus.ready) {
      return;
    }

    await _entriesSub?.cancel();
    await _remoteGoalsSub?.cancel();
    emit(state.copyWith(
      status: LearningGoalStatus.loading,
      userId: userId,
      allEntries: const [],
      clearError: true,
    ));

    final prefs = _prefs ??= await SharedPreferences.getInstance();
    emit(state.copyWith(
      goalMinutesByMonth: _loadGoalMinutesByMonth(prefs, userId),
      updatedAtByMonth: _loadUpdatedAtByMonth(prefs, userId),
      status: LearningGoalStatus.ready,
    ));

    _remoteGoalsSub = _remoteStore.watchGoals(userId).listen((_) async {
      if (isClosed) return;
      await _flushPendingGoals(userId);
      if (isClosed) return;
      await _refreshGoalsFromServer(userId);
    });

    _entriesSub = _watchEntries(userId).listen(
      (entries) {
        if (isClosed) return;
        emit(state.copyWith(
          status: LearningGoalStatus.ready,
          userId: userId,
          allEntries: entries,
          clearError: true,
        ));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (isClosed) return;
        emit(state.copyWith(
          status: LearningGoalStatus.failure,
          error: error.toString(),
        ));
      },
    );

    await _flushPendingGoals(userId);
    await _refreshGoalsFromServer(userId, emitErrors: false);
  }

  Future<void> clearUser() async {
    await _entriesSub?.cancel();
    await _remoteGoalsSub?.cancel();
    emit(const LearningGoalState());
  }

  Future<void> setGoalForMonth(DateTime month, Duration goal) async {
    final userId = state.userId;
    if (userId == null) return;

    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final normalizedMonth = _monthKey(month);
    final nextGoals = Map<String, int>.from(state.goalMinutesByMonth);
    final prefKey = _prefKey(userId, month);

    if (goal.inMinutes <= 0) {
      await prefs.remove(prefKey);
      nextGoals.remove(normalizedMonth);
    } else {
      await prefs.setInt(prefKey, goal.inMinutes);
      nextGoals[normalizedMonth] = goal.inMinutes;
    }

    final nextUpdatedAtByMonth =
        Map<String, DateTime>.from(state.updatedAtByMonth);
    nextUpdatedAtByMonth[normalizedMonth] = DateTime.now().toUtc();

    emit(state.copyWith(
      goalMinutesByMonth: nextGoals,
      updatedAtByMonth: nextUpdatedAtByMonth,
    ));
    await _storePendingSnapshot(
      userId,
      LearningGoalSnapshot(
        goals: nextGoals,
        updatedAtByMonth: nextUpdatedAtByMonth,
      ),
    );

    if (_isOnline) {
      await _pushSnapshotToServer(
        userId,
        LearningGoalSnapshot(
          goals: nextGoals,
          updatedAtByMonth: nextUpdatedAtByMonth,
        ),
      );
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
    LearningGoalSnapshot localSnapshot,
  ) async {
    try {
      final mergedSnapshot =
          await _remoteStore.mergeAndSaveSnapshot(userId, localSnapshot);
      if (isClosed) return;
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await _replaceLocalSnapshotCache(prefs, userId, mergedSnapshot);
      if (isClosed) return;
      emit(state.copyWith(
        goalMinutesByMonth: mergedSnapshot.goals,
        updatedAtByMonth: mergedSnapshot.updatedAtByMonth,
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
        goalMinutesByMonth: remoteSnapshot.goals,
        updatedAtByMonth: remoteSnapshot.updatedAtByMonth,
        status: LearningGoalStatus.ready,
        clearError: true,
      ));
    } catch (error) {
      if (emitErrors) {
        if (isClosed) return;
        emit(state.copyWith(error: error.toString()));
      }
    }
  }

  Future<LearningGoalSnapshot?> _loadPendingSnapshot(String userId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPrefKey(userId));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawGoals = decoded['goals'];
      final rawUpdatedAt = decoded['updated_at'];

      final goals = <String, int>{};
      if (rawGoals is Map) {
        for (final entry in rawGoals.entries) {
          final minutes = int.tryParse(entry.value.toString()) ?? 0;
          if (minutes > 0) {
            goals[entry.key.toString()] = minutes;
          }
        }
      }

      final updatedAtByMonth = <String, DateTime>{};
      if (rawUpdatedAt is Map) {
        for (final entry in rawUpdatedAt.entries) {
          final parsed = DateTime.tryParse(entry.value.toString())?.toUtc();
          if (parsed == null) continue;
          updatedAtByMonth[entry.key.toString()] = parsed;
        }
      }

      return LearningGoalSnapshot(
        goals: goals,
        updatedAtByMonth: updatedAtByMonth,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _storePendingSnapshot(
    String userId,
    LearningGoalSnapshot snapshot,
  ) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final serialized = jsonEncode({
      'goals': snapshot.goals,
      'updated_at': snapshot.updatedAtByMonth
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
    LearningGoalSnapshot snapshot,
  ) async {
    final minutesPrefix = '${AppConstants.learningGoalMinutesKeyPrefix}:$userId:';
    final updatedAtPrefix =
        '${AppConstants.learningGoalUpdatedAtKeyPrefix}:$userId:';

    for (final key in prefs.getKeys()) {
      if (key.startsWith(minutesPrefix) || key.startsWith(updatedAtPrefix)) {
        await prefs.remove(key);
      }
    }

    for (final entry in snapshot.goals.entries) {
      await prefs.setInt('$minutesPrefix${entry.key}', entry.value);
    }
    for (final entry in snapshot.updatedAtByMonth.entries) {
      await prefs.setString(
        '$updatedAtPrefix${entry.key}',
        entry.value.toUtc().toIso8601String(),
      );
    }
  }

  Map<String, int> _loadGoalMinutesByMonth(
    SharedPreferences prefs,
    String userId,
  ) {
    final prefix = '${AppConstants.learningGoalMinutesKeyPrefix}:$userId:';
    final result = <String, int>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final monthKey = key.substring(prefix.length);
      final minutes = prefs.getInt(key);
      if (minutes == null || minutes <= 0) continue;
      result[monthKey] = minutes;
    }

    return result;
  }

  Map<String, DateTime> _loadUpdatedAtByMonth(
    SharedPreferences prefs,
    String userId,
  ) {
    final prefix = '${AppConstants.learningGoalUpdatedAtKeyPrefix}:$userId:';
    final result = <String, DateTime>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final monthKey = key.substring(prefix.length);
      final rawIso = prefs.getString(key);
      final parsed = rawIso != null ? DateTime.tryParse(rawIso)?.toUtc() : null;
      if (parsed == null) continue;
      result[monthKey] = parsed;
    }

    return result;
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _prefKey(String userId, DateTime date) =>
      '${AppConstants.learningGoalMinutesKeyPrefix}:$userId:${_monthKey(date)}';

  static String _pendingPrefKey(String userId) =>
      '${AppConstants.learningGoalPendingKeyPrefix}:$userId';

  @override
  Future<void> close() async {
    await _entriesSub?.cancel();
    await _remoteGoalsSub?.cancel();
    await _connectivitySub?.cancel();
    await super.close();
  }
}