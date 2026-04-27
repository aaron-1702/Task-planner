import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/task.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/calendar/calendar_bloc.dart';
import '../../blocs/task/task_bloc.dart';
import '../../widgets/task_card.dart';
import '../../../config/theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final userId = authState is AuthAuthenticated
            ? authState.user.id
            : null;

        return BlocBuilder<TaskBloc, TaskState>(
          builder: (context, taskState) {
            List<Task> tasksForDay(DateTime day) {
              return taskState.tasks
                  .where((t) =>
                      !t.isDeleted &&
                      t.deadline != null &&
                      isSameDay(t.deadline!, day))
                  .toList();
            }

            return BlocBuilder<CalendarBloc, CalendarState>(
              builder: (context, calState) {
                return Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        title: const Text('Calendar',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        floating: true,
                        snap: true,
                        actions: [
                          TextButton(
                            onPressed: () {
                              if (userId != null) {
                                context.read<CalendarBloc>().add(
                                      CalendarDaySelected(
                                        DateTime.now(),
                                        DateTime.now(),
                                        userId,
                                      ),
                                    );
                              }
                            },
                            child: const Text('Today'),
                          ),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: TableCalendar<Task>(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2100, 12, 31),
                          focusedDay: calState.focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) =>
                              isSameDay(calState.selectedDay, day),
                          eventLoader: tasksForDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        formatButtonDecoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) =>
                            _buildMarkers(context, events),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        if (userId != null) {
                          context.read<CalendarBloc>().add(
                                CalendarDaySelected(
                                    selectedDay, focusedDay, userId),
                              );
                        }
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      onPageChanged: (focusedDay) {
                        if (userId != null) {
                          context.read<CalendarBloc>().add(
                                CalendarPageChanged(focusedDay, userId),
                              );
                        }
                      },
                    ),
                  ),
                  if (calState.selectedDay != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d')
                                  .format(calState.selectedDay!),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => context.pushNamed('task-new',
                                  queryParameters: {
                                    'date': calState.selectedDay!
                                        .toIso8601String(),
                                  }),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Task'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (calState.selectedDayTasks.isEmpty &&
                      calState.selectedDay != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.event_available_outlined,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No tasks this day',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DraggableTaskCard(
                            task: calState.selectedDayTasks[index],
                            userId: userId ?? '',
                          ),
                        ),
                        childCount: calState.selectedDayTasks.length,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  },
  );
}

  Widget? _buildMarkers(BuildContext context, List<Task> events) {
    if (events.isEmpty) return null;

    // Determine the highest priority among all tasks on this day
    final Color dotColor;
    if (events.any((e) => e.priority == TaskPriority.high)) {
      dotColor = AppTheme.priorityHigh;
    } else if (events.any((e) => e.priority == TaskPriority.medium)) {
      dotColor = AppTheme.priorityMedium;
    } else {
      dotColor = AppTheme.priorityLow;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        if (events.length > 1)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor.withOpacity(0.5),
            ),
          ),
      ],
    );
  }
}

class _DraggableTaskCard extends StatelessWidget {
  final Task task;
  final String userId;
  const _DraggableTaskCard(
      {required this.task, required this.userId});

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: TaskCard(task: task),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: TaskCard(task: task),
      ),
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (details) => details.data.id != task.id,
        onAcceptWithDetails: (details) {
          // Swap deadlines between tasks
          final droppedTask = details.data;
          if (task.deadline != null) {
            context.read<CalendarBloc>().add(
                  CalendarTaskDropped(droppedTask, task.deadline!),
                );
          }
        },
        builder: (context, candidateData, rejectedData) => TaskCard(
          task: task,
        ),
      ),
    );
  }
}
