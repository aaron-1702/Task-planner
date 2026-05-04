import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/work_entry_repository.dart';
import '../data/datasources/local/local_database.dart';
import '../data/datasources/remote/supabase_task_datasource.dart';

/// Orchestrates offline-first sync between local SQLite (Drift)
/// and Supabase Realtime.
///
/// Strategy:
///  1. Realtime channel keeps the local DB updated during online sessions.
///  2. On reconnect, pushes local unsynced changes first, then pulls remote.
///  3. Conflict resolution: server wins (last-writer-wins on `updated_at`).
@singleton
class SyncService {
  final TaskRepository _taskRepository;
  final WorkEntryRepository _workEntryRepository;
  final SupabaseTaskDataSource _remote;
  final SupabaseClient _supabase;
  final LocalDatabase _local;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _workEntriesChannel;
  bool _isOnline = true;
  String? _currentUserId;

  SyncService(
    this._taskRepository,
    this._workEntryRepository,
    this._remote,
    this._supabase,
    this._local,
  );

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> start(String userId) async {
    _currentUserId = userId;

    // Monitor connectivity
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Supabase Realtime subscriptions
    _subscribeToRealtime(userId);

    // Always do a full pull on startup to catch tasks from other devices
    await _performFullSync(userId);
    // Pull work entries from all devices
    await _workEntryRepository.syncFromRemote(userId);
  }

  Future<void> stop() async {
    _connectivitySub?.cancel();
    _tasksChannel?.unsubscribe();
    _workEntriesChannel?.unsubscribe();
    _tasksChannel = null;
    _workEntriesChannel = null;
    _currentUserId = null;
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  void _subscribeToRealtime(String userId) {
    _tasksChannel?.unsubscribe();
    _workEntriesChannel?.unsubscribe();

    _tasksChannel = _supabase
        .channel(AppConstants.tasksChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tasksTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onRealtimeChange(payload),
        )
        .subscribe();

    _workEntriesChannel = _supabase
        .channel(AppConstants.workEntriesChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.workEntriesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onWorkEntryRealtimeChange(payload),
        )
        .subscribe();
  }

  void _onRealtimeChange(PostgresChangePayload payload) {
    // On DELETE from another device: remove from local DB directly
    if (payload.eventType == PostgresChangeEvent.delete) {
      final taskId = payload.oldRecord['id'] as String?;
      if (taskId != null) {
        _local.deleteTaskById(taskId);
      }
      return;
    }
    // For INSERT/UPDATE: pull remote changes
    if (_currentUserId != null) {
      _performSync(_currentUserId!);
    }
  }

  void _onWorkEntryRealtimeChange(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final entryId = payload.oldRecord['id'] as String?;
      if (entryId != null) {
        _local.deleteWorkEntryById(entryId);
      }
      return;
    }
    if (_currentUserId != null) {
      _workEntryRepository.syncFromRemote(_currentUserId!);
    }
  }

  // ── Connectivity ───────────────────────────────────────────────────────────

  Future<void> _onConnectivityChanged(
      List<ConnectivityResult> results) async {
    final online = !results.contains(ConnectivityResult.none);

    if (!_isOnline && online) {
      // Came back online — push pending local changes
      _isOnline = true;
      if (_currentUserId != null) {
        await _performSync(_currentUserId!);
      }
    } else {
      _isOnline = online;
    }
  }

  // ── Sync Logic ─────────────────────────────────────────────────────────────

  /// Full sync: pulls ALL remote tasks (ignores lastSync timestamp).
  /// Used on startup to reliably catch tasks from other devices.
  Future<void> _performFullSync(String userId) async {
    final result = await _taskRepository.syncTasks(userId, DateTime.utc(1970));
    result.fold(
      (failure) => null,
      (_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          AppConstants.lastSyncKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      },
    );
  }

  /// Delta sync: pulls only tasks changed since lastSync.
  /// Used on reconnect to avoid re-downloading everything.
  Future<void> _performSync(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(AppConstants.lastSyncKey);
    final lastSync = lastSyncStr != null
        ? DateTime.parse(lastSyncStr)
        : DateTime.utc(1970);

    final result =
        await _taskRepository.syncTasks(userId, lastSync);

    result.fold(
      (failure) => null, // Log silently; offline is expected
      (_) async {
        await prefs.setString(
          AppConstants.lastSyncKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      },
    );
  }

  // ── Manual Trigger ─────────────────────────────────────────────────────────

  Future<void> forceSync() async {
    if (_currentUserId != null) {
      await _performSync(_currentUserId!);
    }
  }

  bool get isOnline => _isOnline;
}
