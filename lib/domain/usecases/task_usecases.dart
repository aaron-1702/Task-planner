import 'package:dartz/dartz.dart' hide Task;
import 'package:injectable/injectable.dart';

import '../entities/task.dart';
import '../repositories/task_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/usecases/usecase.dart';

@injectable
class CreateTaskUseCase implements UseCase<Task, Task> {
  final TaskRepository _repository;
  const CreateTaskUseCase(this._repository);

  @override
  Future<Either<Failure, Task>> call(Task task) =>
      _repository.createTask(task);
}

@injectable
class UpdateTaskUseCase implements UseCase<Task, Task> {
  final TaskRepository _repository;
  const UpdateTaskUseCase(this._repository);

  @override
  Future<Either<Failure, Task>> call(Task task) =>
      _repository.updateTask(task);
}

@injectable
class DeleteTaskUseCase implements UseCase<Unit, String> {
  final TaskRepository _repository;
  const DeleteTaskUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String taskId) =>
      _repository.deleteTask(taskId);
}

@injectable
class GetTasksUseCase implements UseCase<List<Task>, String> {
  final TaskRepository _repository;
  const GetTasksUseCase(this._repository);

  @override
  Future<Either<Failure, List<Task>>> call(String userId) =>
      _repository.getTasksByUser(userId);
}

@injectable
class GetTasksByDateUseCase implements UseCase<List<Task>, GetTasksByDateParams> {
  final TaskRepository _repository;
  const GetTasksByDateUseCase(this._repository);

  @override
  Future<Either<Failure, List<Task>>> call(GetTasksByDateParams params) =>
      _repository.getTasksByDate(params.userId, params.date);
}

@injectable
class WatchTasksUseCase {
  final TaskRepository _repository;
  const WatchTasksUseCase(this._repository);

  Stream<List<Task>> call(String userId) =>
      _repository.watchTasksByUser(userId);
}

class GetTasksByDateParams {
  final String userId;
  final DateTime date;
  const GetTasksByDateParams({required this.userId, required this.date});
}
