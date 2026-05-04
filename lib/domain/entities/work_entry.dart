import 'package:equatable/equatable.dart';

class WorkEntry extends Equatable {
  final String id;
  final String userId;

  /// Calendar date of the work entry (time part is ignored).
  final DateTime date;

  /// Absolute start timestamp (UTC).
  final DateTime startTime;

  /// Absolute end timestamp (UTC).
  final DateTime endTime;

  /// Break duration in minutes (manually entered).
  final int breakMinutes;

  /// Optional free-text note / activity description.
  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const WorkEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Net working time after subtracting breaks.
  Duration get workDuration =>
      endTime.difference(startTime) - Duration(minutes: breakMinutes);

  /// Gross working time (start → end, no break deduction).
  Duration get grossDuration => endTime.difference(startTime);

  WorkEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    int? breakMinutes,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      WorkEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        breakMinutes: breakMinutes ?? this.breakMinutes,
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
        note,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
