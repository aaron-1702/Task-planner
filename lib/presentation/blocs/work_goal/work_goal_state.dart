part of 'work_goal_cubit.dart';

enum WorkGoalStatus { initial, loading, ready, failure }

class WorkGoalState extends Equatable {
  final WorkGoalStatus status;
  final String? userId;
  final List<WorkEntry> allEntries;
  final Map<String, int> goalMinutesByMonth;
  final Map<String, DateTime> updatedAtByMonth;
  final String? error;

  const WorkGoalState({
    this.status = WorkGoalStatus.initial,
    this.userId,
    this.allEntries = const [],
    this.goalMinutesByMonth = const {},
    this.updatedAtByMonth = const {},
    this.error,
  });

  Duration goalForMonth(DateTime month) {
    return Duration(minutes: goalMinutesByMonth[_monthKey(month)] ?? 0);
  }

  Duration workedForMonth(DateTime month) {
    final totalMinutes = allEntries
        .where((entry) => _isSameMonth(entry.date.toLocal(), month))
        .fold<int>(0, (sum, entry) => sum + entry.workDuration.inMinutes);
    return Duration(minutes: totalMinutes);
  }

  Duration remainingForMonth(DateTime month) {
    final remainingMinutes =
        goalForMonth(month).inMinutes - workedForMonth(month).inMinutes;
    return Duration(minutes: remainingMinutes > 0 ? remainingMinutes : 0);
  }

  double progressForMonth(DateTime month) {
    final goalMinutes = goalForMonth(month).inMinutes;
    if (goalMinutes <= 0) return 0;

    return (workedForMonth(month).inMinutes / goalMinutes).clamp(0, 1)
        as double;
  }

  bool hasGoalForMonth(DateTime month) => goalForMonth(month).inMinutes > 0;

  WorkGoalState copyWith({
    WorkGoalStatus? status,
    String? userId,
    List<WorkEntry>? allEntries,
    Map<String, int>? goalMinutesByMonth,
    Map<String, DateTime>? updatedAtByMonth,
    String? error,
    bool clearError = false,
  }) {
    return WorkGoalState(
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
