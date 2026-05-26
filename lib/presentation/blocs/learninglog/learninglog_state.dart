part of 'learninglog_bloc.dart';

enum LearninglogStatus { initial, loading, success, failure }

class LearninglogState extends Equatable {
  final LearninglogStatus status;
  final List<LearningEntry> allEntries;
  final LearninglogViewMode viewMode;
  final DateTime selectedDate;
  final bool timerRunning;
  final DateTime? timerStartedAt;
  final String? error;
  final String? exportCsv;

  const LearninglogState({
    this.status = LearninglogStatus.initial,
    this.allEntries = const [],
    this.viewMode = LearninglogViewMode.day,
    required this.selectedDate,
    this.timerRunning = false,
    this.timerStartedAt,
    this.error,
    this.exportCsv,
  });

  List<LearningEntry> get periodEntries {
    final range = _periodRange;
    final startInt = _ymd(range.$1);
    final endInt = _ymd(range.$2);

    return allEntries.where((e) {
      final d = e.date.toLocal();
      final v = _ymd(d);
      return v >= startInt && v <= endInt;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Duration get periodTotalLearning => periodEntries.fold(
        Duration.zero,
        (acc, e) => acc + e.learningDuration,
      );

  String get periodLabel {
    final range = _periodRange;
    switch (viewMode) {
      case LearninglogViewMode.day:
        return _fmtDate(range.$1);
      case LearninglogViewMode.week:
        return '${_fmtShort(range.$1)} - ${_fmtShort(range.$2)}';
      case LearninglogViewMode.month:
        return _fmtMonth(range.$1);
    }
  }

  (DateTime, DateTime) get _periodRange {
    final d = selectedDate;
    switch (viewMode) {
      case LearninglogViewMode.day:
        final s = DateTime(d.year, d.month, d.day);
        return (s, s);
      case LearninglogViewMode.week:
        final monday = d.subtract(Duration(days: d.weekday - 1));
        final s = DateTime(monday.year, monday.month, monday.day);
        return (s, s.add(const Duration(days: 6)));
      case LearninglogViewMode.month:
        final s = DateTime(d.year, d.month, 1);
        final e = DateTime(d.year, d.month + 1, 0);
        return (s, e);
    }
  }

  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

    static String _fmtDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

    static String _fmtShort(DateTime d) => DateFormat('dd.MM.').format(d);

    static String _fmtMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);

  LearninglogState copyWith({
    LearninglogStatus? status,
    List<LearningEntry>? allEntries,
    LearninglogViewMode? viewMode,
    DateTime? selectedDate,
    bool? timerRunning,
    DateTime? timerStartedAt,
    bool clearTimerStart = false,
    String? error,
    bool clearError = false,
    String? exportCsv,
    bool clearExport = false,
  }) =>
      LearninglogState(
        status: status ?? this.status,
        allEntries: allEntries ?? this.allEntries,
        viewMode: viewMode ?? this.viewMode,
        selectedDate: selectedDate ?? this.selectedDate,
        timerRunning: timerRunning ?? this.timerRunning,
        timerStartedAt:
            clearTimerStart ? null : (timerStartedAt ?? this.timerStartedAt),
        error: clearError ? null : (error ?? this.error),
        exportCsv: clearExport ? null : (exportCsv ?? this.exportCsv),
      );

  @override
  List<Object?> get props => [
        status,
        allEntries,
        viewMode,
        selectedDate,
        timerRunning,
        timerStartedAt,
        error,
        exportCsv,
      ];
}
