import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';
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
  final SupabaseTaskDataSource _remote;
  final SupabaseClient _supabase;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  RealtimeChannel? _tasksChannel;
  bool _isOnline = true;
  String? _currentUserId;

  SyncService(this._taskRepository, this._remote, this._supabase);

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> start(String userId) async {
    _currentUserId = userId;

    // Monitor connectivity
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Supabase Realtime subscription
    _subscribeToRealtime(userId);

    // Initial sync on startup
    await _performSync(userId);
  }

  Future<void> stop() async {
    _connectivitySub?.cancel();
    _tasksChannel?.unsubscribe();
    _tasksChannel = null;
    _currentUserId = null;
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  void _subscribeToRealtime(String userId) {
    _tasksChannel?.unsubscribe();

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
  }

  void _onRealtimeChange(PostgresChangePayload payload) {
    // The Drift stream already reflects changes because the remote DS
    // writes through to local. But if we want to handle server-push
    // (e.g., changes from another device), we sync again.
    if (_currentUserId != null) {
      _performSync(_currentUserId!);
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
