part of 'daily_goal_cubit.dart';

enum DailyGoalStatus { initial, loading, ready, failure }

class DailyGoalForDate extends Equatable {
  final String id;
  final String title;
  final bool isCompleted;

  const DailyGoalForDate({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  @override
  List<Object?> get props => [id, title, isCompleted];
}

class DailyGoalState extends Equatable {
  final DailyGoalStatus status;
  final String? userId;
  final List<DailyGoalTemplate> templates;
  final Map<String, Map<String, bool>> completionsByDate;
  final Map<String, DateTime> updatedAtByKey;
  final String? error;

  const DailyGoalState({
    this.status = DailyGoalStatus.initial,
    this.userId,
    this.templates = const [],
    this.completionsByDate = const {},
    this.updatedAtByKey = const {},
    this.error,
  });

  List<DailyGoalForDate> goalsForDate(DateTime date) {
    final completedGoals = completionsByDate[DailyGoalCubit._dateKey(date)] ??
        const <String, bool>{};

    return templates
        .map(
          (template) => DailyGoalForDate(
            id: template.id,
            title: template.title,
            isCompleted: completedGoals[template.id] == true,
          ),
        )
        .toList(growable: false);
  }

  int completedCountForDate(DateTime date) {
    return goalsForDate(date).where((goal) => goal.isCompleted).length;
  }

  double progressForDate(DateTime date) {
    if (templates.isEmpty) return 0;
    return completedCountForDate(date) / templates.length;
  }

  DailyGoalState copyWith({
    DailyGoalStatus? status,
    String? userId,
    List<DailyGoalTemplate>? templates,
    Map<String, Map<String, bool>>? completionsByDate,
    Map<String, DateTime>? updatedAtByKey,
    String? error,
    bool clearError = false,
  }) {
    return DailyGoalState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      templates: templates ?? this.templates,
      completionsByDate: completionsByDate ?? this.completionsByDate,
      updatedAtByKey: updatedAtByKey ?? this.updatedAtByKey,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        userId,
        templates.map((template) => '${template.id}:${template.title}').toList(),
        completionsByDate.entries
            .map(
              (entry) =>
                  '${entry.key}:${(entry.value.entries.toList()..sort((left, right) => left.key.compareTo(right.key))).map((completion) => '${completion.key}:${completion.value}').join(',')}',
            )
            .toList()
          ..sort(),
        updatedAtByKey.entries
            .map((entry) => '${entry.key}:${entry.value.toIso8601String()}')
            .toList()
          ..sort(),
        error,
      ];
}