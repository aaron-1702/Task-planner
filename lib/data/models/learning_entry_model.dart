import '../../domain/entities/learning_entry.dart';

class LearningEntryModel extends LearningEntry {
  const LearningEntryModel({
    required super.id,
    required super.userId,
    required super.date,
    required super.startTime,
    required super.endTime,
    super.breakMinutes,
    required super.topic,
    super.note,
    required super.createdAt,
    required super.updatedAt,
    super.isDeleted,
  });

  factory LearningEntryModel.fromEntity(LearningEntry e) => LearningEntryModel(
        id: e.id,
        userId: e.userId,
        date: e.date,
        startTime: e.startTime,
        endTime: e.endTime,
        breakMinutes: e.breakMinutes,
        topic: e.topic,
        note: e.note,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
      );

  factory LearningEntryModel.fromJson(Map<String, dynamic> json) =>
      LearningEntryModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        date: DateTime.parse(json['date'] as String),
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        breakMinutes: json['break_minutes'] as int? ?? 0,
        topic: json['topic'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isDeleted: json['is_deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'date': '${date.year}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'break_minutes': breakMinutes,
        'topic': topic,
        'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
      };
}
