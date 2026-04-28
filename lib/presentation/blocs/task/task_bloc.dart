import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/task.dart';
import '../../../domain/usecases/task_usecases.dart';

part 'task_event.dart';
part 'task_state.dart';

@injectable
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final CreateTaskUseCase _createTask;
  final UpdateTaskUseCase _updateTask;
  final DeleteTaskUseCase _deleteTask;
  final GetTasksUseCase _getTasks;
  final WatchTasksUseCase _watchTasks;

  StreamSubscription<List<Task>>? _tasksSubscription;
  final _uuid = const Uuid();

  TaskBloc(
    this._createTask,
    this._updateTask,
    this._deleteTask,
    this._getTasks,
    this._watchTasks,
  ) : super(const TaskState()) {
    on<TaskSubscriptionRequested>(_onSubscriptionRequested);
    on<TaskCreated>(_onCreated);
    on<TaskUpdated>(_onUpdated);
    on<TaskDeleted>(_onDeleted);
    on<TaskStatusChanged>(_onStatusChanged);
    on<TaskFilterChanged>(_onFilterChanged);
  }

  Future<void> _onSubscriptionRequested(
      TaskSubscriptionRequested event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskLoadStatus.loading));

    await _tasksSubscription?.cancel();
    await emit.forEach<List<Task>>(
      _watchTasks(event.userId),
      onData: (tasks) => state.copyWith(
        status: TaskLoadStatus.success,
        tasks: tasks,
      ),
      onError: (e, _) => state.copyWith(
        status: TaskLoadStatus.failure,
        error: e.toString(),
      ),
    );
  }

  Future<void> _onCreated(
      TaskCreated event, Emitter<TaskState> emit) async {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: _uuid.v4(),
      userId: event.userId,
      title: event.title,
      description: event.description,
      deadline: event.deadline,
      priority: event.priority,
      status: TaskStatus.open,
      tags: event.tags,
      categoryId: event.categoryId,
      recurrenceRule: event.recurrenceRule,
      createdAt: now,
      updatedAt: now,
      estimatedMinutes: event.estimatedMinutes,
      subtasks: event.subtasks,
    );

    final result = await _createTask(task);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  Future<void> _onUpdated(
      TaskUpdated event, Emitter<TaskState> emit) async {
    final result =
        await _updateTask(event.task.copyWith(updatedAt: DateTime.now().toUtc()));
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  Future<void> _onDeleted(
      TaskDeleted event, Emitter<TaskState> emit) async {
    final result = await _deleteTask(event.taskId);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  Future<void> _onStatusChanged(
      TaskStatusChanged event, Emitter<TaskState> emit) async {
    final task = state.tasks
        .firstWhere((t) => t.id == event.taskId)
        .copyWith(
          status: event.newStatus,
          updatedAt: DateTime.now().toUtc(),
        );
    final result = await _updateTask(task);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  void _onFilterChanged(
      TaskFilterChanged event, Emitter<TaskState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  List<Task> get filteredTasks {
    final filter = state.filter;
    var tasks = state.tasks;

    if (filter.status != null) {
      tasks = tasks.where((t) => t.status == filter.status).toList();
    }
    if (filter.priority != null) {
      tasks = tasks.where((t) => t.priority == filter.priority).toList();
    }
    if (filter.categoryId != null) {
      tasks =
          tasks.where((t) => t.categoryId == filter.categoryId).toList();
    }
    if (filter.query != null && filter.query!.isNotEmpty) {
      final q = filter.query!.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return tasks;
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }
}
