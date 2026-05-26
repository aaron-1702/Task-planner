import 'package:equatable/equatable.dart';

class LearningEntry extends Equatable {
  final String id;
  final String userId;

  /// Calendar date of the learning entry (time part is ignored).
  final DateTime date;

  /// Absolute start timestamp (UTC).
  final DateTime startTime;

  /// Absolute end timestamp (UTC).
  final DateTime endTime;

  /// Break duration in minutes.
  final int breakMinutes;

  /// Learning topic, e.g. "Flutter", "Math", "Algorithms".
  final String topic;

  /// Optional notes for what was learned.
  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const LearningEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
    required this.topic,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Net learning time after subtracting breaks.
  Duration get learningDuration =>
      endTime.difference(startTime) - Duration(minutes: breakMinutes);

  Duration get grossDuration => endTime.difference(startTime);

  LearningEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    int? breakMinutes,
    String? topic,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      LearningEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        topic: topic ?? this.topic,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        date,
        startTime,
        endTime,
        breakMinutes,
        topic,
        note,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
