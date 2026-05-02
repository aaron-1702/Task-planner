import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/entities/calendar_event.dart';
import '../../../data/repositories/calendar_event_repository.dart';
import '../../../services/notification_service.dart';

part 'cal_event_event.dart';
part 'cal_event_state.dart';

@injectable
class CalendarEventBloc
    extends Bloc<CalendarEventBlocEvent, CalendarEventState> {
  final CalendarEventRepository _repo;
  final NotificationService _notifications;

  CalendarEventBloc(this._repo, this._notifications)
      : super(const CalendarEventState()) {
    on<CalendarEventSubscriptionRequested>(_onSubscribed);
    on<CalendarEventCreated>(_onCreated);
    on<CalendarEventUpdated>(_onUpdated);
    on<CalendarEventDeleted>(_onDeleted);
  }

  Future<void> _onSubscribed(
      CalendarEventSubscriptionRequested event,
      Emitter<CalendarEventState> emit) async {
    await emit.forEach(
      _repo.watchEventsByUser(event.userId),
      onData: (events) => state.copyWith(events: events, error: null),
      onError: (e, _) => state.copyWith(error: e.toString()),
    );
  }

  Future<void> _onCreated(
      CalendarEventCreated event, Emitter<CalendarEventState> emit) async {
    final result = await _repo.createEvent(event.event);
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (saved) {
        if (saved.reminderMinutes != null) {
          _notifications.scheduleEventReminder(saved);
        }
      },
    );
  }

  Future<void> _onUpdated(
      CalendarEventUpdated event, Emitter<CalendarEventState> emit) async {
    await _notifications.cancelEventReminder(event.event.id);
    final result = await _repo.updateEvent(event.event);
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (saved) {
        if (saved.reminderMinutes != null) {
          _notifications.scheduleEventReminder(saved);
        }
      },
    );
  }

  Future<void> _onDeleted(
      CalendarEventDeleted event, Emitter<CalendarEventState> emit) async {
    await _notifications.cancelEventReminder(event.eventId);
    final result = await _repo.deleteEvent(event.eventId, event.userId);
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (_) => null,
    );
  }
}
