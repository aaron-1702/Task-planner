import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../models/task_model.dart';

/// Remote data source backed by Supabase.
/// Handles all HTTP calls + Realtime subscriptions.
@injectable
class SupabaseTaskDataSource {
  final SupabaseClient _client;

  SupabaseTaskDataSource(this._client);

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<TaskModel> createTask(TaskModel task) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .insert(task.toJson())
        .select()
        .single();
    return TaskModel.fromJson(response);
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .update(task.toJson())
        .eq('id', task.id)
        .eq('user_id', task.userId) // RLS safety
        .select()
        .single();
    return TaskModel.fromJson(response);
  }

  Future<void> deleteTask(String taskId, String userId) async {
    // Soft delete: set is_deleted = true
    await _client
        .from(AppConstants.tasksTable)
        .update({'is_deleted': true, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', taskId)
        .eq('user_id', userId);
  }

  Future<TaskModel> getTaskById(String taskId) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .select()
        .eq('id', taskId)
        .single();
    return TaskModel.fromJson(response);
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<List<TaskModel>> getTasksByUser(String userId) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);
    return (response as List).map((e) => TaskModel.fromJson(e)).toList();
  }

  Future<List<TaskModel>> getTasksSince(
      String userId, DateTime since) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .select()
        .eq('user_id', userId)
        .gte('updated_at', since.toUtc().toIso8601String())
        .order('updated_at', ascending: false);
    return (response as List).map((e) => TaskModel.fromJson(e)).toList();
  }

  Future<List<TaskModel>> getTasksByDateRange(
      String userId, DateTime start, DateTime end) async {
    final response = await _client
        .from(AppConstants.tasksTable)
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .gte('deadline', start.toUtc().toIso8601String())
        .lt('deadline', end.toUtc().toIso8601String())
        .order('deadline', ascending: true);
    return (response as List).map((e) => TaskModel.fromJson(e)).toList();
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  Stream<List<TaskModel>> watchTasksByUser(String userId) {
    // Uses Supabase Realtime postgres_changes
    return _client
        .from(AppConstants.tasksTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .map((data) => data
            .where((row) => row['is_deleted'] == false)
            .map((e) => TaskModel.fromJson(e))
            .toList());
  }

  // ── Upsert (used during sync) ─────────────────────────────────────────────

  Future<void> upsertTasks(List<TaskModel> tasks) async {
    if (tasks.isEmpty) return;
    await _client
        .from(AppConstants.tasksTable)
        .upsert(tasks.map((t) => t.toJson()).toList());
  }
}
