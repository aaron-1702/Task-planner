part of 'worklog_bloc.dart';

enum WorklogViewMode { day, week, month }

abstract class WorklogEvent extends Equatable {
  const WorklogEvent();
  @override
  List<Object?> get props => [];
}

/// Start watching entries for [userId].
class WorklogSubscriptionRequested extends WorklogEvent {
  final String userId;
  const WorklogSubscriptionRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

/// Change the displayed date (moves the period window).
class WorklogDateChanged extends WorklogEvent {
  final DateTime date;
  const WorklogDateChanged(this.date);
  @override
  List<Object?> get props => [date];
}

/// Switch between Day / Week / Month view.
class WorklogViewModeChanged extends WorklogEvent {
  final WorklogViewMode mode;
  const WorklogViewModeChanged(this.mode);
  @override
  List<Object?> get props => [mode];
}

/// Save a new work entry (create or update).
class WorklogEntrySaved extends WorklogEvent {
  final String? existingId; // null = new entry
  final String userId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int breakMinutes;
  final String? note;

  const WorklogEntrySaved({
    this.existingId,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
    this.note,
  });

  @override
  List<Object?> get props =>
      [existingId, userId, date, startTime, endTime, breakMinutes, note];
}

/// Delete a work entry.
class WorklogEntryDeleted extends WorklogEvent {
  final String entryId;
  final String userId;
  const WorklogEntryDeleted({required this.entryId, required this.userId});
  @override
  List<Object?> get props => [entryId, userId];
}

/// Start the live timer.
class WorklogTimerStarted extends WorklogEvent {
  const WorklogTimerStarted();
}

/// Stop the live timer and optionally save the resulting entry.
class WorklogTimerStopped extends WorklogEvent {
  final String userId;
  final int breakMinutes;
  final String? note;
  const WorklogTimerStopped({
    required this.userId,
    this.breakMinutes = 0,
    this.note,
  });
  @override
  List<Object?> get props => [userId, breakMinutes, note];
}

/// Request a CSV export of the current period.
class WorklogExportRequested extends WorklogEvent {
  const WorklogExportRequested();
}

/// Clear the export CSV after it has been shown.
class WorklogExportDismissed extends WorklogEvent {
  const WorklogExportDismissed();
}
