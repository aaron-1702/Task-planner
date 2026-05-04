part of 'worklog_bloc.dart';

enum WorklogStatus { initial, loading, success, failure }

class WorklogState extends Equatable {
  final WorklogStatus status;
  final List<WorkEntry> allEntries; // all for current userId
  final WorklogViewMode viewMode;
  final DateTime selectedDate;
  final bool timerRunning;
  final DateTime? timerStartedAt;
  final String? error;
  final String? exportCsv; // populated after export

  const WorklogState({
    this.status = WorklogStatus.initial,
    this.allEntries = const [],
    this.viewMode = WorklogViewMode.day,
    required this.selectedDate,
    this.timerRunning = false,
    this.timerStartedAt,
    this.error,
    this.exportCsv,
  });

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Entries visible in the current period window.
  List<WorkEntry> get periodEntries {
    final range = _periodRange;
    final startInt = _ymd(range.$1);
    final endInt   = _ymd(range.$2);
    return allEntries
        .where((e) => _ymd(e.date.toLocal()) >= startInt &&
                      _ymd(e.date.toLocal()) <= endInt)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Integer representation YYYYMMDD for reliable date-only comparison.
  static int _ymd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Total net working time for the current period.
  Duration get periodTotalWork => periodEntries.fold(
        Duration.zero,
        (acc, e) => acc + e.workDuration,
      );

  /// (start, end) of the currently displayed period, both at day boundaries.
  (DateTime, DateTime) get _periodRange {
    final d = selectedDate;
    switch (viewMode) {
      case WorklogViewMode.day:
        final s = DateTime(d.year, d.month, d.day);
        return (s, s);
      case WorklogViewMode.week:
        final monday = d.subtract(Duration(days: d.weekday - 1));
        final s = DateTime(monday.year, monday.month, monday.day);
        return (s, s.add(const Duration(days: 6)));
      case WorklogViewMode.month:
        final s = DateTime(d.year, d.month, 1);
        final e = DateTime(d.year, d.month + 1, 0);
        return (s, e);
    }
  }

  /// Label for the current period (shown in the date navigator).
  String get periodLabel {
    final r = _periodRange;
    switch (viewMode) {
      case WorklogViewMode.day:
        return _fmtDate(r.$1);
      case WorklogViewMode.week:
        return '${_fmtShort(r.$1)} – ${_fmtShort(r.$2)}';
      case WorklogViewMode.month:
        return '${_monthName(r.$1.month)} ${r.$1.year}';
    }
  }

  WorklogState copyWith({
    WorklogStatus? status,
    List<WorkEntry>? allEntries,
    WorklogViewMode? viewMode,
    DateTime? selectedDate,
    bool? timerRunning,
    DateTime? timerStartedAt,
    bool clearTimerStart = false,
    String? error,
    String? exportCsv,
    bool clearExport = false,
  }) =>
      WorklogState(
        status: status ?? this.status,
        allEntries: allEntries ?? this.allEntries,
        viewMode: viewMode ?? this.viewMode,
        selectedDate: selectedDate ?? this.selectedDate,
        timerRunning: timerRunning ?? this.timerRunning,
        timerStartedAt:
            clearTimerStart ? null : (timerStartedAt ?? this.timerStartedAt),
        error: error ?? this.error,
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

  // ── Formatting helpers ─────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _monthName(int m) => _months[m];
}
