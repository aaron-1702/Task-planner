part of 'cal_event_bloc.dart';

abstract class CalendarEventBlocEvent {}

class CalendarEventSubscriptionRequested extends CalendarEventBlocEvent {
  final String userId;
  CalendarEventSubscriptionRequested(this.userId);
}

class CalendarEventCreated extends CalendarEventBlocEvent {
  final CalendarEvent event;
  CalendarEventCreated(this.event);
}

class CalendarEventUpdated extends CalendarEventBlocEvent {
  final CalendarEvent event;
  CalendarEventUpdated(this.event);
}

class CalendarEventDeleted extends CalendarEventBlocEvent {
  final String eventId;
  final String userId;
  CalendarEventDeleted(this.eventId, this.userId);
}
