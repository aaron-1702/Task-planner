part of 'learning_goal_cubit.dart';

enum LearningGoalStatus { initial, loading, ready, failure }

class LearningGoalState extends Equatable {
  final LearningGoalStatus status;
  final String? userId;
  final List<LearningEntry> allEntries;
  final Map<String, int> goalMinutesByMonth;
  final Map<String, DateTime> updatedAtByMonth;
  final String? error;

  const LearningGoalState({
    this.status = LearningGoalStatus.initial,
    this.userId,
    this.allEntries = const [],
    this.goalMinutesByMonth = const {},
    this.updatedAtByMonth = const {},
    this.error,
  });

  Duration goalForMonth(DateTime month) {
    return Duration(minutes: goalMinutesByMonth[_monthKey(month)] ?? 0);
  }

  Duration learnedForMonth(DateTime month) {
    final totalMinutes = allEntries
        .where((entry) => _isSameMonth(entry.date.toLocal(), month))
        .fold<int>(0, (sum, entry) => sum + entry.learningDuration.inMinutes);
    return Duration(minutes: totalMinutes);
  }

  Duration remainingForMonth(DateTime month) {
    final remainingMinutes =
        goalForMonth(month).inMinutes - learnedForMonth(month).inMinutes;
    return Duration(minutes: remainingMinutes > 0 ? remainingMinutes : 0);
  }

  double progressForMonth(DateTime month) {
    final goalMinutes = goalForMonth(month).inMinutes;
    if (goalMinutes <= 0) return 0;

    return (learnedForMonth(month).inMinutes / goalMinutes).clamp(0, 1)
        as double;
  }

  bool hasGoalForMonth(DateTime month) => goalForMonth(month).inMinutes > 0;

  LearningGoalState copyWith({
    LearningGoalStatus? status,
    String? userId,
    List<LearningEntry>? allEntries,
    Map<String, int>? goalMinutesByMonth,
    Map<String, DateTime>? updatedAtByMonth,
    String? error,
    bool clearError = false,
  }) {
    return LearningGoalState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      allEntries: allEntries ?? this.allEntries,
      goalMinutesByMonth: goalMinutesByMonth ?? this.goalMinutesByMonth,
      updatedAtByMonth: updatedAtByMonth ?? this.updatedAtByMonth,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static bool _isSameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
        status,
        userId,
        allEntries,
        goalMinutesByMonth.entries
            .map((entry) => '${entry.key}:${entry.value}')
            .toList(),
        updatedAtByMonth.entries
          .map((entry) => '${entry.key}:${entry.value.toIso8601String()}')
          .toList(),
        error,
      ];
}