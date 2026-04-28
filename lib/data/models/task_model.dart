import 'dart:convert';
import 'package:flutter/material.dart';

import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.deadline,
    super.priority,
    super.status,
    super.tags,
    super.categoryId,
    super.recurrenceRule,
    required super.createdAt,
    required super.updatedAt,
    super.isDeleted,
    super.estimatedMinutes,
    super.pomodoroCount,
    super.subtasks,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      priority: _parsePriority(json['priority'] as String?),
      status: _parseStatus(json['status'] as String?),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : const [],
      categoryId: json['category_id'] as String?,
      recurrenceRule: json['recurrence_rule'] != null
          ? RecurrenceRuleModel.fromJson(
              json['recurrence_rule'] is String
                  ? jsonDecode(json['recurrence_rule'] as String)
                  : json['recurrence_rule'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      estimatedMinutes: json['estimated_minutes'] as int?,
      pomodoroCount: json['pomodoro_count'] as int?,
      subtasks: json['subtasks'] != null
          ? (json['subtasks'] is String
              ? (jsonDecode(json['subtasks'] as String) as List)
              : (json['subtasks'] as List))
              .map((e) => Subtask(
                    id: e['id'] as String,
                    title: e['title'] as String,
                    isDone: e['is_done'] as bool? ?? false,
                  ))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'deadline': deadline?.toUtc().toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'tags': tags,
      'category_id': categoryId,
      'recurrence_rule': recurrenceRule != null
          ? (recurrenceRule as RecurrenceRuleModel).toJson()
          : null,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'estimated_minutes': estimatedMinutes,
      'pomodoro_count': pomodoroCount,
      'subtasks': subtasks
          .map((s) => {'id': s.id, 'title': s.title, 'is_done': s.isDone})
          .toList(),
    };
  }

  static TaskPriority _parsePriority(String? value) {
    switch (value) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }

  static TaskStatus _parseStatus(String? value) {
    switch (value) {
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      default:
        return TaskStatus.open;
    }
  }

  factory TaskModel.fromEntity(Task task) {
    return TaskModel(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      deadline: task.deadline,
      priority: task.priority,
      status: task.status,
      tags: task.tags,
      categoryId: task.categoryId,
      recurrenceRule: task.recurrenceRule,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      isDeleted: task.isDeleted,
      estimatedMinutes: task.estimatedMinutes,
      pomodoroCount: task.pomodoroCount,
      subtasks: task.subtasks,
    );
  }
}

class RecurrenceRuleModel extends RecurrenceRule {
  const RecurrenceRuleModel({
    required super.type,
    super.interval,
    super.weekDays,
    super.endDate,
    super.maxOccurrences,
  });

  factory RecurrenceRuleModel.fromJson(Map<String, dynamic> json) {
    return RecurrenceRuleModel(
      type: RecurrenceType.values.byName(json['type'] as String),
      interval: json['interval'] as int? ?? 1,
      weekDays: json['week_days'] != null
          ? List<int>.from(json['week_days'] as List)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      maxOccurrences: json['max_occurrences'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'interval': interval,
        'week_days': weekDays,
        'end_date': endDate?.toUtc().toIso8601String(),
        'max_occurrences': maxOccurrences,
      };
}
