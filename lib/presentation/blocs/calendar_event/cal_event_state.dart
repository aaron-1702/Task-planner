part of 'cal_event_bloc.dart';

class CalendarEventState {
  final List<CalendarEvent> events;
  final String? error;

  const CalendarEventState({this.events = const [], this.error});

  List<CalendarEvent> eventsForDay(DateTime day) =>
      events.where((e) => !e.isDeleted && e.occursOnDay(day)).toList();

  CalendarEventState copyWith(
      {List<CalendarEvent>? events, String? error}) {
    return CalendarEventState(
      events: events ?? this.events,
      error: error,
    );
  }
}
