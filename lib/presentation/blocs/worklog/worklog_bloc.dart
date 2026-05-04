import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/work_entry.dart';
import '../../../domain/usecases/work_entry_usecases.dart';

part 'worklog_event.dart';
part 'worklog_state.dart';

@injectable
class WorklogBloc extends Bloc<WorklogEvent, WorklogState> {
  final WatchWorkEntriesUseCase _watchEntries;
  final CreateWorkEntryUseCase _createEntry;
  final UpdateWorkEntryUseCase _updateEntry;
  final DeleteWorkEntryUseCase _deleteEntry;
  final SyncWorkEntriesUseCase _syncEntries;

  StreamSubscription<List<WorkEntry>>? _entriesSub;
  final _uuid = const Uuid();

  WorklogBloc(
    this._watchEntries,
    this._createEntry,
    this._updateEntry,
    this._deleteEntry,
    this._syncEntries,
  ) : super(WorklogState(selectedDate: DateTime.now())) {
    on<WorklogSubscriptionRequested>(_onSubscriptionRequested);
    on<WorklogDateChanged>(_onDateChanged);
    on<WorklogViewModeChanged>(_onViewModeChanged);
    on<WorklogEntrySaved>(_onEntrySaved);
    on<WorklogEntryDeleted>(_onEntryDeleted);
    on<WorklogTimerStarted>(_onTimerStarted);
    on<WorklogTimerStopped>(_onTimerStopped);
    on<WorklogExportRequested>(_onExportRequested);
    on<WorklogExportDismissed>(
        (_, emit) => emit(state.copyWith(clearExport: true)));
  }

  // ── Subscription ───────────────────────────────────────────────────────────

  Future<void> _onSubscriptionRequested(
      WorklogSubscriptionRequested event, Emitter<WorklogState> emit) async {
    emit(state.copyWith(status: WorklogStatus.loading));

    await _entriesSub?.cancel();
    await emit.forEach<List<WorkEntry>>(
      _watchEntries(event.userId),
      onData: (entries) => state.copyWith(
        status: WorklogStatus.success,
        allEntries: entries,
      ),
      onError: (e, _) => state.copyWith(
        status: WorklogStatus.failure,
        error: e.toString(),
      ),
    );

    // Kick off a background sync
    _syncEntries(event.userId);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onDateChanged(WorklogDateChanged event, Emitter<WorklogState> emit) {
    emit(state.copyWith(selectedDate: event.date));
  }

  void _onViewModeChanged(
      WorklogViewModeChanged event, Emitter<WorklogState> emit) {
    emit(state.copyWith(viewMode: event.mode));
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> _onEntrySaved(
      WorklogEntrySaved event, Emitter<WorklogState> emit) async {
    final now = DateTime.now().toUtc();
    final isNew = event.existingId == null;

    final entry = WorkEntry(
      id: isNew ? _uuid.v4() : event.existingId!,
      userId: event.userId,
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      breakMinutes: event.breakMinutes,
      note: event.note,
      createdAt: now,
      updatedAt: now,
    );

    final result = isNew
        ? await _createEntry(entry)
        : await _updateEntry(entry);

    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  Future<void> _onEntryDeleted(
      WorklogEntryDeleted event, Emitter<WorklogState> emit) async {
    final result = await _deleteEntry(event.entryId, event.userId);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => null,
    );
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _onTimerStarted(
      WorklogTimerStarted event, Emitter<WorklogState> emit) {
    emit(state.copyWith(
      timerRunning: true,
      timerStartedAt: DateTime.now().toUtc(),
    ));
  }

  Future<void> _onTimerStopped(
      WorklogTimerStopped event, Emitter<WorklogState> emit) async {
    if (!state.timerRunning || state.timerStartedAt == null) return;

    final startUtc = state.timerStartedAt!;
    final end = DateTime.now().toUtc();
    // Convert start to LOCAL to extract the correct calendar date
    final startLocal = startUtc.toLocal();

    emit(state.copyWith(
      timerRunning: false,
      clearTimerStart: true,
    ));

    // Persist as a new entry
    add(WorklogEntrySaved(
      userId: event.userId,
      date: DateTime(startLocal.year, startLocal.month, startLocal.day),
      startTime: startUtc,
      endTime: end,
      breakMinutes: event.breakMinutes,
      note: event.note,
    ));
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  void _onExportRequested(
      WorklogExportRequested event, Emitter<WorklogState> emit) {
    final entries = state.periodEntries;
    final buf = StringBuffer();
    buf.writeln('Date,Start,End,Break (min),Net Hours,Note');

    for (final e in entries) {
      final net = e.workDuration.inMinutes / 60.0;
      buf.writeln(
        '${_fmt(e.date)},'
        '${_fmtTime(e.startTime)},'
        '${_fmtTime(e.endTime)},'
        '${e.breakMinutes},'
        '${net.toStringAsFixed(2)},'
        '"${(e.note ?? '').replaceAll('"', '""')}"',
      );
    }

    emit(state.copyWith(exportCsv: buf.toString()));
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Future<void> close() {
    _entriesSub?.cancel();
    return super.close();
  }
}
