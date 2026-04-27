part of 'task_bloc.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class TaskSubscriptionRequested extends TaskEvent {
  final String userId;
  const TaskSubscriptionRequested(this.userId);
  @override
  List<Object> get props => [userId];
}

class TaskCreated extends TaskEvent {
  final String userId;
  final String title;
  final String? description;
  final DateTime? deadline;
  final TaskPriority priority;
  final List<String> tags;
  final String? categoryId;
  final RecurrenceRule? recurrenceRule;
  final int? estimatedMinutes;

  const TaskCreated({
    required this.userId,
    required this.title,
    this.description,
    this.deadline,
    this.priority = TaskPriority.medium,
    this.tags = const [],
    this.categoryId,
    this.recurrenceRule,
    this.estimatedMinutes,
  });

  @override
  List<Object?> get props => [
        userId, title, description, deadline, priority,
        tags, categoryId, recurrenceRule, estimatedMinutes,
      ];
}

class TaskUpdated extends TaskEvent {
  final Task task;
  const TaskUpdated(this.task);
  @override
  List<Object> get props => [task];
}

class TaskDeleted extends TaskEvent {
  final String taskId;
  const TaskDeleted(this.taskId);
  @override
  List<Object> get props => [taskId];
}

class TaskStatusChanged extends TaskEvent {
  final String taskId;
  final TaskStatus newStatus;
  const TaskStatusChanged(this.taskId, this.newStatus);
  @override
  List<Object> get props => [taskId, newStatus];
}

class TaskFilterChanged extends TaskEvent {
  final TaskFilter filter;
  const TaskFilterChanged(this.filter);
  @override
  List<Object> get props => [filter];
}

class _TasksUpdated extends TaskEvent {
  final List<Task> tasks;
  const _TasksUpdated(this.tasks);
  @override
  List<Object> get props => [tasks];
}
