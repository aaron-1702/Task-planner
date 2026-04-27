import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/entities/task.dart';
import '../../../domain/usecases/task_usecases.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

@injectable
class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetTasksByDateUseCase _getTasksByDate;
  final UpdateTaskUseCase _updateTask;

  CalendarBloc(this._getTasksByDate, this._updateTask)
      : super(CalendarState(focusedDay: DateTime.now())) {
    on<CalendarPageChanged>(_onPageChanged);
    on<CalendarDaySelected>(_onDaySelected);
    on<CalendarTasksRequested>(_onTasksRequested);
    on<CalendarTaskDropped>(_onTaskDropped);
  }

  Future<void> _onPageChanged(
      CalendarPageChanged event, Emitter<CalendarState> emit) async {
    emit(state.copyWith(focusedDay: event.focusedDay));
    add(CalendarTasksRequested(
      userId: event.userId,
      month: event.focusedDay,
    ));
  }

  Future<void> _onDaySelected(
      CalendarDaySelected event, Emitter<CalendarState> emit) async {
    emit(state.copyWith(
      selectedDay: event.selectedDay,
      focusedDay: event.focusedDay,
    ));
    final result = await _getTasksByDate(GetTasksByDateParams(
        userId: event.userId, date: event.selectedDay));
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (tasks) => emit(state.copyWith(selectedDayTasks: tasks)),
    );
  }

  Future<void> _onTasksRequested(
      CalendarTasksRequested event, Emitter<CalendarState> emit) async {
    // Load tasks for the visible month range
    final start = DateTime(event.month.year, event.month.month - 1, 1);
    final end = DateTime(event.month.year, event.month.month + 2, 0);
    final result = await _getTasksByDate(
        GetTasksByDateParams(userId: event.userId, date: event.month));
    result.fold(
      (failure) => null,
      (tasks) {
        // Build event map (date -> tasks)
        final map = <DateTime, List<Task>>{};
        for (final task in tasks) {
          if (task.deadline != null) {
            final key = DateTime(task.deadline!.year, task.deadline!.month,
                task.deadline!.day);
            map[key] = [...(map[key] ?? []), task];
          }
        }
        emit(state.copyWith(tasksByDay: map));
      },
    );
  }

  Future<void> _onTaskDropped(
      CalendarTaskDropped event, Emitter<CalendarState> emit) async {
    final updatedTask = event.task.copyWith(
      deadline: event.newDate,
      updatedAt: DateTime.now().toUtc(),
    );
    final result = await _updateTask(updatedTask);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => add(CalendarTasksRequested(
          userId: event.task.userId, month: state.focusedDay)),
    );
  }
}
