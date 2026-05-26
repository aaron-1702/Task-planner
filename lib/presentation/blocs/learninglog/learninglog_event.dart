part of 'learninglog_bloc.dart';

enum LearninglogViewMode { day, week, month }

abstract class LearninglogEvent extends Equatable {
  const LearninglogEvent();

  @override
  List<Object?> get props => [];
}

class LearninglogSubscriptionRequested extends LearninglogEvent {
  final String userId;
  const LearninglogSubscriptionRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LearninglogDateChanged extends LearninglogEvent {
  final DateTime date;
  const LearninglogDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class LearninglogViewModeChanged extends LearninglogEvent {
  final LearninglogViewMode mode;
  const LearninglogViewModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

class LearninglogEntrySaved extends LearninglogEvent {
  final String? existingId;
  final String userId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int breakMinutes;
  final String topic;
  final String? note;

  const LearninglogEntrySaved({
    this.existingId,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
    required this.topic,
    this.note,
  });

  @override
  List<Object?> get props => [
        existingId,
        userId,
        date,
        startTime,
        endTime,
        breakMinutes,
        topic,
        note,
      ];
}

class LearninglogEntryDeleted extends LearninglogEvent {
  final String entryId;
  final String userId;

  const LearninglogEntryDeleted({required this.entryId, required this.userId});

  @override
  List<Object?> get props => [entryId, userId];
}

class LearninglogTimerStarted extends LearninglogEvent {
  const LearninglogTimerStarted();
}

class LearninglogTimerStopped extends LearninglogEvent {
  final String userId;
  final int breakMinutes;
  final String topic;
  final String? note;

  const LearninglogTimerStopped({
    required this.userId,
    this.breakMinutes = 0,
    required this.topic,
    this.note,
  });

  @override
  List<Object?> get props => [userId, breakMinutes, topic, note];
}

class LearninglogExportRequested extends LearninglogEvent {
  const LearninglogExportRequested();
}

class LearninglogExportDismissed extends LearninglogEvent {
  const LearninglogExportDismissed();
}
