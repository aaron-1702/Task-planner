import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/learning_entry.dart';
import '../../../domain/usecases/learning_entry_usecases.dart';

part 'learninglog_event.dart';
part 'learninglog_state.dart';

@injectable
class LearninglogBloc extends Bloc<LearninglogEvent, LearninglogState> {
  final WatchLearningEntriesUseCase _watchEntries;
  final CreateLearningEntryUseCase _createEntry;
  final UpdateLearningEntryUseCase _updateEntry;
  final DeleteLearningEntryUseCase _deleteEntry;
  final SyncLearningEntriesUseCase _syncEntries;
  final ExportLearningEntriesCsvUseCase _exportCsv;

  final _uuid = const Uuid();
  StreamSubscription<List<LearningEntry>>? _entriesSub;

  LearninglogBloc(
    this._watchEntries,
    this._createEntry,
    this._updateEntry,
    this._deleteEntry,
    this._syncEntries,
    this._exportCsv,
  ) : super(LearninglogState(selectedDate: DateTime.now())) {
    on<LearninglogSubscriptionRequested>(_onSubscriptionRequested);
    on<LearninglogDateChanged>(_onDateChanged);
    on<LearninglogViewModeChanged>(_onViewModeChanged);
    on<LearninglogEntrySaved>(_onEntrySaved);
    on<LearninglogEntryDeleted>(_onEntryDeleted);
    on<LearninglogTimerStarted>(_onTimerStarted);
    on<LearninglogTimerStopped>(_onTimerStopped);
    on<LearninglogExportRequested>(_onExportRequested);
    on<LearninglogExportDismissed>(
      (_, emit) => emit(state.copyWith(clearExport: true)),
    );
  }

  Future<void> _onSubscriptionRequested(
    LearninglogSubscriptionRequested event,
    Emitter<LearninglogState> emit,
  ) async {
    emit(state.copyWith(status: LearninglogStatus.loading, clearError: true));

    await _entriesSub?.cancel();
    await emit.forEach<List<LearningEntry>>(
      _watchEntries(event.userId),
      onData: (entries) => state.copyWith(
        status: LearninglogStatus.success,
        allEntries: entries,
      ),
      onError: (e, _) => state.copyWith(
        status: LearninglogStatus.failure,
        error: e.toString(),
      ),
    );

    _syncEntries(event.userId);
  }

  void _onDateChanged(
      LearninglogDateChanged event, Emitter<LearninglogState> emit) {
    emit(state.copyWith(selectedDate: event.date));
  }

  void _onViewModeChanged(
    LearninglogViewModeChanged event,
    Emitter<LearninglogState> emit,
  ) {
    emit(state.copyWith(viewMode: event.mode));
  }

  Future<void> _onEntrySaved(
    LearninglogEntrySaved event,
    Emitter<LearninglogState> emit,
  ) async {
    final now = DateTime.now().toUtc();
    final isNew = event.existingId == null;

    final gross = event.endTime.difference(event.startTime);
    if (!event.endTime.isAfter(event.startTime)) {
      emit(state.copyWith(error: 'Endzeit muss nach Startzeit liegen.'));
      return;
    }
    if (event.breakMinutes < 0) {
      emit(state.copyWith(error: 'Pause darf nicht negativ sein.'));
      return;
    }
    if (Duration(minutes: event.breakMinutes) > gross) {
      emit(state.copyWith(
          error: 'Pause darf nicht groesser als die Dauer sein.'));
      return;
    }

    final entry = LearningEntry(
      id: isNew ? _uuid.v4() : event.existingId!,
      userId: event.userId,
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      breakMinutes: event.breakMinutes,
      topic: event.topic,
      note: event.note,
      createdAt: now,
      updatedAt: now,
    );

    final result =
        isNew ? await _createEntry(entry) : await _updateEntry(entry);

    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => emit(state.copyWith(clearError: true)),
    );
  }

  Future<void> _onEntryDeleted(
    LearninglogEntryDeleted event,
    Emitter<LearninglogState> emit,
  ) async {
    final result = await _deleteEntry(event.entryId, event.userId);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => emit(state.copyWith(clearError: true)),
    );
  }

  void _onTimerStarted(
    LearninglogTimerStarted event,
    Emitter<LearninglogState> emit,
  ) {
    emit(state.copyWith(
      timerRunning: true,
      timerStartedAt: DateTime.now().toUtc(),
      clearError: true,
    ));
  }

  Future<void> _onTimerStopped(
    LearninglogTimerStopped event,
    Emitter<LearninglogState> emit,
  ) async {
    if (!state.timerRunning || state.timerStartedAt == null) return;

    final startUtc = state.timerStartedAt!;
    final end = DateTime.now().toUtc();
    final startLocal = startUtc.toLocal();

    emit(state.copyWith(
      timerRunning: false,
      clearTimerStart: true,
    ));

    add(LearninglogEntrySaved(
      userId: event.userId,
      date: DateTime(startLocal.year, startLocal.month, startLocal.day),
      startTime: startUtc,
      endTime: end,
      breakMinutes: event.breakMinutes,
      topic: event.topic,
      note: event.note,
    ));
  }

  void _onExportRequested(
    LearninglogExportRequested event,
    Emitter<LearninglogState> emit,
  ) {
    final csv = _exportCsv(state.periodEntries);
    emit(state.copyWith(exportCsv: csv));
  }

  @override
  Future<void> close() {
    _entriesSub?.cancel();
    return super.close();
  }
}
