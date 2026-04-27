part of 'calendar_bloc.dart';

class CalendarState extends Equatable {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final List<Task> selectedDayTasks;
  final Map<DateTime, List<Task>> tasksByDay;
  final String? error;

  const CalendarState({
    required this.focusedDay,
    this.selectedDay,
    this.selectedDayTasks = const [],
    this.tasksByDay = const {},
    this.error,
  });

  List<Task> getTasksForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return tasksByDay[key] ?? [];
  }

  CalendarState copyWith({
    DateTime? focusedDay,
    DateTime? selectedDay,
    List<Task>? selectedDayTasks,
    Map<DateTime, List<Task>>? tasksByDay,
    String? error,
  }) {
    return CalendarState(
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedDayTasks: selectedDayTasks ?? this.selectedDayTasks,
      tasksByDay: tasksByDay ?? this.tasksByDay,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [focusedDay, selectedDay, selectedDayTasks, tasksByDay, error];
}
