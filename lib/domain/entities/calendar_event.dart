import 'package:equatable/equatable.dart';

enum CalendarEventType { event, birthday }

enum EventRecurrence { none, daily, weekly, monthly, yearly }

class CalendarEvent extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final CalendarEventType type;
  final EventRecurrence recurrence;
  final int? reminderMinutes; // null = no reminder
  final int? birthYear;       // for age calculation on birthdays
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.type = CalendarEventType.event,
    this.recurrence = EventRecurrence.none,
    this.reminderMinutes,
    this.birthYear,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Whether this event falls on [day] (including recurring instances).
  bool occursOnDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    if (start.isAfter(d)) return false;

    if (isSameDay(start, d)) return true;

    switch (recurrence) {
      case EventRecurrence.none:
        return false;
      case EventRecurrence.daily:
        return true;
      case EventRecurrence.weekly:
        return start.weekday == d.weekday;
      case EventRecurrence.monthly:
        return start.day == d.day;
      case EventRecurrence.yearly:
        return start.month == d.month && start.day == d.day;
    }
  }

  /// Returns age this year if birthYear is set, otherwise null.
  int? get ageThisYear {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    CalendarEventType? type,
    EventRecurrence? recurrence,
    int? reminderMinutes,
    int? birthYear,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      birthYear: birthYear ?? this.birthYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, description, startDate, endDate,
        type, recurrence, reminderMinutes, birthYear,
        createdAt, updatedAt, isDeleted,
      ];
}
