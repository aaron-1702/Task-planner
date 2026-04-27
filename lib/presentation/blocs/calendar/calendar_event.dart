part of 'calendar_bloc.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();
  @override
  List<Object?> get props => [];
}

class CalendarPageChanged extends CalendarEvent {
  final DateTime focusedDay;
  final String userId;
  const CalendarPageChanged(this.focusedDay, this.userId);
  @override
  List<Object> get props => [focusedDay, userId];
}

class CalendarDaySelected extends CalendarEvent {
  final DateTime selectedDay;
  final DateTime focusedDay;
  final String userId;
  const CalendarDaySelected(this.selectedDay, this.focusedDay, this.userId);
  @override
  List<Object> get props => [selectedDay, focusedDay, userId];
}

class CalendarTasksRequested extends CalendarEvent {
  final String userId;
  final DateTime month;
  const CalendarTasksRequested({required this.userId, required this.month});
  @override
  List<Object> get props => [userId, month];
}

class CalendarTaskDropped extends CalendarEvent {
  final Task task;
  final DateTime newDate;
  const CalendarTaskDropped(this.task, this.newDate);
  @override
  List<Object> get props => [task, newDate];
}
