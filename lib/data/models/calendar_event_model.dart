import '../../domain/entities/calendar_event.dart';

class CalendarEventModel extends CalendarEvent {
  const CalendarEventModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    required super.startDate,
    super.endDate,
    super.type,
    super.recurrence,
    super.reminderMinutes,
    super.birthYear,
    required super.createdAt,
    required super.updatedAt,
    super.isDeleted,
  });

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      type: CalendarEventType.values.byName(
          (json['type'] as String?) ?? 'event'),
      recurrence: EventRecurrence.values.byName(
          (json['recurrence'] as String?) ?? 'none'),
      reminderMinutes: json['reminder_minutes'] as int?,
      birthYear: json['birth_year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
        'type': type.name,
        'recurrence': recurrence.name,
        'reminder_minutes': reminderMinutes,
        'birth_year': birthYear,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
      };

  static CalendarEventModel fromEntity(CalendarEvent e) =>
      CalendarEventModel(
        id: e.id,
        userId: e.userId,
        title: e.title,
        description: e.description,
        startDate: e.startDate,
        endDate: e.endDate,
        type: e.type,
        recurrence: e.recurrence,
        reminderMinutes: e.reminderMinutes,
        birthYear: e.birthYear,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
      );
}
