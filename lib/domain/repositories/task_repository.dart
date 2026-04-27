import 'package:dartz/dartz.dart' hide Task;

import '../entities/task.dart';
import '../../core/errors/failures.dart';

abstract class TaskRepository {
  // CRUD
  Future<Either<Failure, Task>> createTask(Task task);
  Future<Either<Failure, Task>> updateTask(Task task);
  Future<Either<Failure, Unit>> deleteTask(String taskId);
  Future<Either<Failure, Task>> getTaskById(String taskId);

  // Queries
  Future<Either<Failure, List<Task>>> getTasksByUser(String userId);
  Future<Either<Failure, List<Task>>> getTasksByDate(
      String userId, DateTime date);
  Future<Either<Failure, List<Task>>> getTasksByDateRange(
      String userId, DateTime start, DateTime end);
  Future<Either<Failure, List<Task>>> getTasksByCategory(
      String userId, String categoryId);
  Future<Either<Failure, List<Task>>> searchTasks(
      String userId, String query);

  // Realtime stream
  Stream<List<Task>> watchTasksByUser(String userId);
  Stream<List<Task>> watchTasksByDate(String userId, DateTime date);

  // Bulk operations
  Future<Either<Failure, Unit>> syncTasks(
      String userId, DateTime since);

  // Recurring tasks
  Future<Either<Failure, List<Task>>> generateRecurringInstances(
      Task template, DateTime rangeStart, DateTime rangeEnd);
}
