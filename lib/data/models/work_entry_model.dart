import '../../domain/entities/work_entry.dart';

class WorkEntryModel extends WorkEntry {
  const WorkEntryModel({
    required super.id,
    required super.userId,
    required super.date,
    required super.startTime,
    required super.endTime,
    super.breakMinutes,
    super.note,
    required super.createdAt,
    required super.updatedAt,
    super.isDeleted,
  });

  factory WorkEntryModel.fromEntity(WorkEntry e) => WorkEntryModel(
        id: e.id,
        userId: e.userId,
        date: e.date,
        startTime: e.startTime,
        endTime: e.endTime,
        breakMinutes: e.breakMinutes,
        note: e.note,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
      );

  factory WorkEntryModel.fromJson(Map<String, dynamic> json) => WorkEntryModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        date: DateTime.parse(json['date'] as String),
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        breakMinutes: json['break_minutes'] as int? ?? 0,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isDeleted: json['is_deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'date': date.toUtc().toIso8601String(),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'break_minutes': breakMinutes,
        'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
      };
}
