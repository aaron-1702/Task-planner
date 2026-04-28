import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart' hide DataClass;
import 'package:dartz/dartz.dart' hide Task;
import 'package:injectable/injectable.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/supabase_task_datasource.dart';
import '../models/task_model.dart';

@Injectable(as: TaskRepository)
class TaskRepositoryImpl implements TaskRepository {
  final SupabaseTaskDataSource _remote;
  final LocalDatabase _local;

  TaskRepositoryImpl(this._remote, this._local);

  // ── Create ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Task>> createTask(Task task) async {
    try {
      final model = TaskModel.fromEntity(task);

      // Write locally first (optimistic)
      await _local.upsertTask(_taskModelToTableData(model, isSynced: false));

      try {
        // Sync to remote
        final remoteModel = await _remote.createTask(model);
        await _local.upsertTask(
            _taskModelToTableData(remoteModel, isSynced: true));
        return Right(remoteModel);
      } catch (_) {
        // Offline: will sync later
        return Right(model);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Task>> updateTask(Task task) async {
    try {
      final model = TaskModel.fromEntity(task);

      await _local.upsertTask(_taskModelToTableData(model, isSynced: false));

      try {
        final remoteModel = await _remote.updateTask(model);
        await _local.upsertTask(
            _taskModelToTableData(remoteModel, isSynced: true));
        return Right(remoteModel);
      } catch (_) {
        return Right(model);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> deleteTask(String taskId) async {
    try {
      // Mark locally deleted
      final existing = await (_local.select(_local.tasksTable)
            ..where((t) => t.id.equals(taskId)))
          .getSingle();

      await _local.upsertTask(existing.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now().toUtc(),
        isSynced: false,
      ));

      try {
        await _remote.deleteTask(taskId, existing.userId);
        await _local.markTaskSynced(taskId);
      } catch (_) {
        // Will sync later
      }
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Get By ID ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Task>> getTaskById(String taskId) async {
    try {
      final task = await (_local.select(_local.tasksTable)
            ..where((t) => t.id.equals(taskId)))
          .getSingleOrNull();
      if (task != null) return Right(_tableDataToModel(task));

      final remote = await _remote.getTaskById(taskId);
      await _local.upsertTask(_taskModelToTableData(remote, isSynced: true));
      return Right(remote);
    } catch (e) {
      return Left(NotFoundFailure(e.toString()));
    }
  }

  // ── List ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Task>>> getTasksByUser(String userId) async {
    try {
      // Return local first
      final local = await (_local.select(_local.tasksTable)
            ..where((t) => Expression.and(
                [t.userId.equals(userId), t.isDeleted.equals(false)]))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();
      return Right(local.map(_tableDataToModel).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Task>>> getTasksByDate(
      String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day + 1);
      final all = await (_local.select(_local.tasksTable)
            ..where((t) => Expression.and(
                [t.userId.equals(userId), t.isDeleted.equals(false)])))
          .get();
      final local = all
          .where((t) =>
              t.deadline != null &&
              !t.deadline!.isBefore(startOfDay) &&
              t.deadline!.isBefore(endOfDay))
          .toList();
      return Right(local.map(_tableDataToModel).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Task>>> getTasksByDateRange(
      String userId, DateTime start, DateTime end) async {
    try {
      final all = await (_local.select(_local.tasksTable)
            ..where((t) => Expression.and(
                [t.userId.equals(userId), t.isDeleted.equals(false)])))
          .get();
      final local = all
          .where((t) =>
              t.deadline != null &&
              !t.deadline!.isBefore(start) &&
              t.deadline!.isBefore(end))
          .toList();
      return Right(local.map(_tableDataToModel).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Task>>> getTasksByCategory(
      String userId, String categoryId) async {
    try {
      final local = await (_local.select(_local.tasksTable)
            ..where((t) => Expression.and([
              t.userId.equals(userId),
              t.categoryId.equals(categoryId),
              t.isDeleted.equals(false),
            ])))
          .get();
      return Right(local.map(_tableDataToModel).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Task>>> searchTasks(
      String userId, String query) async {
    try {
      final all = await (_local.select(_local.tasksTable)
            ..where((t) => Expression.and(
                [t.userId.equals(userId), t.isDeleted.equals(false)])))
          .get();
      final filtered = all
          .where((t) =>
              t.title.toLowerCase().contains(query.toLowerCase()) ||
              (t.description?.toLowerCase().contains(query.toLowerCase()) ??
                  false))
          .map(_tableDataToModel)
          .toList();
      return Right(filtered);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  @override
  Stream<List<Task>> watchTasksByUser(String userId) {
    return _local.watchTasksByUser(userId).map(
          (rows) => rows.map(_tableDataToModel).toList(),
        );
  }

  @override
  Stream<List<Task>> watchTasksByDate(String userId, DateTime date) {
    return _local.watchTasksByDate(userId, date).map(
          (rows) => rows.map(_tableDataToModel).toList(),
        );
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> syncTasks(
      String userId, DateTime since) async {
    try {
      // 1. Push unsynced local changes
      final unsynced = await _local.getUnsyncedTasks();
      if (unsynced.isNotEmpty) {
        final toDelete = unsynced.where((t) => t.isDeleted).toList();
        final toUpsert = unsynced.where((t) => !t.isDeleted).toList();

        if (toUpsert.isNotEmpty) {
          final models =
              toUpsert.map(_tableDataToModel).map(TaskModel.fromEntity).toList();
          await _remote.upsertTasks(models);
          for (final t in toUpsert) {
            await _local.markTaskSynced(t.id);
          }
        }

        for (final t in toDelete) {
          await _remote.deleteTask(t.id, t.userId);
          await _local.markTaskSynced(t.id);
        }
      }

      // 2. Pull remote changes since last sync
      final remoteChanges = await _remote.getTasksSince(userId, since);
      if (remoteChanges.isNotEmpty) {
        await _local.upsertTasks(remoteChanges
            .map((m) => _taskModelToTableData(m, isSynced: true))
            .toList());
      }

      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Recurring ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Task>>> generateRecurringInstances(
      Task template, DateTime rangeStart, DateTime rangeEnd) async {
    final rule = template.recurrenceRule;
    if (rule == null || rule.type == RecurrenceType.none) {
      return const Right([]);
    }

    final instances = <Task>[];
    var current = template.deadline ?? rangeStart;
    int count = 0;

    while (current.isBefore(rangeEnd)) {
      if (current.isAfter(rangeStart) || current.isAtSameMomentAs(rangeStart)) {
        instances.add(template.copyWith(
          deadline: current,
          id: '${template.id}_${current.millisecondsSinceEpoch}',
        ));
      }
      count++;
      if (rule.maxOccurrences != null && count >= rule.maxOccurrences!) break;
      if (rule.endDate != null && current.isAfter(rule.endDate!)) break;

      switch (rule.type) {
        case RecurrenceType.daily:
          current = current.add(Duration(days: rule.interval));
          break;
        case RecurrenceType.weekly:
          current = current.add(Duration(days: 7 * rule.interval));
          break;
        case RecurrenceType.monthly:
          current = DateTime(
              current.year, current.month + rule.interval, current.day,
              current.hour, current.minute);
          break;
        default:
          break;
      }
    }

    return Right(instances);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _recurrenceRuleToJson(RecurrenceRule rule) => {
        'type': rule.type.name,
        'interval': rule.interval,
        'week_days': rule.weekDays,
        'end_date': rule.endDate?.toUtc().toIso8601String(),
        'max_occurrences': rule.maxOccurrences,
      };

  Task _tableDataToModel(TasksTableData data) {
    return TaskModel(
      id: data.id,
      userId: data.userId,
      title: data.title,
      description: data.description,
      deadline: data.deadline,
      priority: TaskPriority.values.byName(data.priority),
      status: TaskStatus.values.byName(data.status),
      tags: List<String>.from(
          (data.tags.isNotEmpty ? jsonDecode(data.tags) : []) as List),
      categoryId: data.categoryId,
      recurrenceRule: data.recurrenceRule != null
          ? RecurrenceRuleModel.fromJson(
              jsonDecode(data.recurrenceRule!) as Map<String, dynamic>)
          : null,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      isDeleted: data.isDeleted,
      estimatedMinutes: data.estimatedMinutes,
      pomodoroCount: data.pomodoroCount,
      subtasks: data.subtasks.isNotEmpty
          ? (jsonDecode(data.subtasks) as List)
              .map((e) => Subtask(
                    id: e['id'] as String,
                    title: e['title'] as String,
                    isDone: e['is_done'] as bool? ?? false,
                  ))
              .toList()
          : const [],
    );
  }

  TasksTableData _taskModelToTableData(TaskModel model,
      {required bool isSynced}) {
    return TasksTableData(
      id: model.id,
      userId: model.userId,
      title: model.title,
      description: model.description,
      deadline: model.deadline,
      priority: model.priority.name,
      status: model.status.name,
      tags: jsonEncode(model.tags),
      categoryId: model.categoryId,
      recurrenceRule: model.recurrenceRule != null
          ? jsonEncode(_recurrenceRuleToJson(model.recurrenceRule!))
          : null,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isDeleted: model.isDeleted,
      estimatedMinutes: model.estimatedMinutes,
      pomodoroCount: model.pomodoroCount,
      subtasks: jsonEncode(model.subtasks
          .map((s) => {'id': s.id, 'title': s.title, 'is_done': s.isDone})
          .toList()),
      isSynced: isSynced,
    );
  }
}
