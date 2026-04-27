part of 'task_bloc.dart';

enum TaskLoadStatus { initial, loading, success, failure }

class TaskFilter extends Equatable {
  final TaskStatus? status;
  final TaskPriority? priority;
  final String? categoryId;
  final String? query;

  const TaskFilter({this.status, this.priority, this.categoryId, this.query});

  TaskFilter copyWith({
    TaskStatus? status,
    TaskPriority? priority,
    String? categoryId,
    String? query,
  }) {
    return TaskFilter(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      query: query ?? this.query,
    );
  }

  bool get isEmpty =>
      status == null && priority == null && categoryId == null &&
      (query == null || query!.isEmpty);

  @override
  List<Object?> get props => [status, priority, categoryId, query];
}

class TaskState extends Equatable {
  final TaskLoadStatus status;
  final List<Task> tasks;
  final TaskFilter filter;
  final String? error;

  const TaskState({
    this.status = TaskLoadStatus.initial,
    this.tasks = const [],
    this.filter = const TaskFilter(),
    this.error,
  });

  List<Task> get todayTasks {
    final now = DateTime.now();
    return tasks
        .where((t) =>
            t.isDueToday && t.status != TaskStatus.done && !t.isDeleted)
        .toList()
      ..sort((a, b) {
        // Sort by priority desc, then by deadline asc
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }
        return 0;
      });
  }

  List<Task> get overdueTasks => tasks
      .where((t) => t.isOverdue && !t.isDeleted)
      .toList()
    ..sort((a, b) => (a.deadline ?? DateTime.now())
        .compareTo(b.deadline ?? DateTime.now()));

  int get completedCount =>
      tasks.where((t) => t.status == TaskStatus.done).length;
  int get totalCount => tasks.where((t) => !t.isDeleted).length;
  double get completionRate =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  TaskState copyWith({
    TaskLoadStatus? status,
    List<Task>? tasks,
    TaskFilter? filter,
    String? error,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, tasks, filter, error];
}
