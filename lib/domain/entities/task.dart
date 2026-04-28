import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { open, inProgress, done }

enum RecurrenceType { none, daily, weekly, monthly, custom }

class Subtask extends Equatable {
  final String id;
  final String title;
  final bool isDone;

  const Subtask({required this.id, required this.title, this.isDone = false});

  Subtask copyWith({String? id, String? title, bool? isDone}) =>
      Subtask(
        id: id ?? this.id,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
      );

  @override
  List<Object?> get props => [id, title, isDone];
}

class Task extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? deadline;
  final TaskPriority priority;
  final TaskStatus status;
  final List<String> tags;
  final String? categoryId;
  final RecurrenceRule? recurrenceRule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int? estimatedMinutes;
  final int? pomodoroCount;
  final List<Subtask> subtasks;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.deadline,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.open,
    this.tags = const [],
    this.categoryId,
    this.recurrenceRule,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.estimatedMinutes,
    this.pomodoroCount,
    this.subtasks = const [],
  });

  bool get isOverdue =>
      deadline != null &&
      deadline!.isBefore(DateTime.now()) &&
      status != TaskStatus.done;

  bool get isDueToday {
    if (deadline == null) return false;
    final now = DateTime.now();
    return deadline!.year == now.year &&
        deadline!.month == now.month &&
        deadline!.day == now.day;
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? deadline,
    TaskPriority? priority,
    TaskStatus? status,
    List<String>? tags,
    String? categoryId,
    RecurrenceRule? recurrenceRule,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? estimatedMinutes,
    int? pomodoroCount,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      categoryId: categoryId ?? this.categoryId,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, description, deadline, priority, status,
        tags, categoryId, recurrenceRule, createdAt, updatedAt,
        isDeleted, estimatedMinutes, pomodoroCount, subtasks,
      ];
}

class RecurrenceRule extends Equatable {
  final RecurrenceType type;
  final int interval;           // every N days/weeks/months
  final List<int>? weekDays;    // 1=Mon … 7=Sun for weekly
  final DateTime? endDate;
  final int? maxOccurrences;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.weekDays,
    this.endDate,
    this.maxOccurrences,
  });

  @override
  List<Object?> get props =>
      [type, interval, weekDays, endDate, maxOccurrences];
}
