import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/calendar_event.dart';
import '../../../domain/entities/task.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/calendar/calendar_bloc.dart' hide CalendarEvent;
import '../../blocs/calendar_event/cal_event_bloc.dart';
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
        final userId =
            authState is AuthAuthenticated ? authState.user.id : null;

        return BlocBuilder<TaskBloc, TaskState>(
          builder: (context, taskState) {
            return BlocBuilder<CalendarEventBloc, CalendarEventState>(
              builder: (context, evState) {
                List<Task> tasksForDay(DateTime day) => taskState.tasks
                    .where((t) =>
                        !t.isDeleted &&
                        t.deadline != null &&
                        isSameDay(t.deadline!, day))
                    .toList();

                List<CalendarEvent> eventsForDay(DateTime day) =>
                    evState.eventsForDay(day);

                bool hasBirthdayOnDay(DateTime day) => eventsForDay(day)
                    .any((e) => e.type == CalendarEventType.birthday);

                return BlocBuilder<CalendarBloc, CalendarState>(
                  builder: (context, calState) {
                    final selectedDay = calState.selectedDay;
                    final selectedTasks = selectedDay != null
                        ? tasksForDay(selectedDay)
                        : <Task>[];
                    final selectedEvents = selectedDay != null
                        ? eventsForDay(selectedDay)
                        : <CalendarEvent>[];

                    return Scaffold(
                      body: CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            title: const Text('Calendar',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
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
                                              userId),
                                        );
                                  }
                                },
                                child: const Text('Today'),
                              ),
                            ],
                          ),
                          SliverToBoxAdapter(
                            child: TableCalendar<Object>(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2200, 12, 31),
                              focusedDay: calState.focusedDay,
                              calendarFormat: _calendarFormat,
                              selectedDayPredicate: (day) =>
                                  isSameDay(calState.selectedDay, day),
                              eventLoader: (day) => [
                                ...tasksForDay(day),
                                ...eventsForDay(day),
                              ],
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              headerStyle: HeaderStyle(
                                formatButtonDecoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (ctx, day, events) =>
                                    _buildMarkers(
                                        ctx, day, events, hasBirthdayOnDay(day)),
                              ),
                              onDaySelected: (sel, focused) {
                                if (userId != null) {
                                  context.read<CalendarBloc>().add(
                                        CalendarDaySelected(
                                            sel, focused, userId),
                                      );
                                }
                              },
                              onFormatChanged: (f) =>
                                  setState(() => _calendarFormat = f),
                              onPageChanged: (focused) {
                                if (userId != null) {
                                  context.read<CalendarBloc>().add(
                                        CalendarPageChanged(
                                            focused, userId),
                                      );
                                }
                              },
                            ),
                          ),

                          // Selected-day header
                          if (selectedDay != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('EEEE, MMMM d')
                                            .format(selectedDay),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          context.pushNamed('event-new',
                                              queryParameters: {
                                            'date': selectedDay
                                                .toIso8601String(),
                                          }),
                                      icon: const Icon(
                                          Icons.event_outlined,
                                          size: 18),
                                      label: const Text('Add Event'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          context.pushNamed('task-new',
                                              queryParameters: {
                                            'date': selectedDay
                                                .toIso8601String(),
                                          }),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Task'),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Events for selected day
                          if (selectedEvents.isNotEmpty)
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _EventCard(
                                      event: selectedEvents[i],
                                      userId: userId ?? '',
                                    ),
                                  ),
                                  childCount: selectedEvents.length,
                                ),
                              ),
                            ),

                          // Empty state
                          if (selectedEvents.isEmpty &&
                              selectedTasks.isEmpty &&
                              selectedDay != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.event_available_outlined,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Nothing scheduled',
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

                          // Tasks for selected day
                          SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _DraggableTaskCard(
                                    task: selectedTasks[index],
                                    userId: userId ?? '',
                                  ),
                                ),
                                childCount: selectedTasks.length,
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
      },
    );
  }

  Widget? _buildMarkers(BuildContext context, DateTime day,
      List<Object> events, bool hasBirthday) {
    if (events.isEmpty) return null;
    final tasks = events.whereType<Task>().toList();
    final calEvents = events.whereType<CalendarEvent>().toList();

    Color dotColor;
    if (tasks.any((e) => e.priority == TaskPriority.high)) {
      dotColor = AppTheme.priorityHigh;
    } else if (tasks.any((e) => e.priority == TaskPriority.medium)) {
      dotColor = AppTheme.priorityMedium;
    } else {
      dotColor = AppTheme.priorityLow;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasBirthday)
          const Text('🎂', style: TextStyle(fontSize: 10)),
        if (calEvents.any((e) => e.type != CalendarEventType.birthday))
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.teal),
          ),
        if (tasks.isNotEmpty)
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: dotColor),
          ),
      ],
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final String userId;
  const _EventCard({required this.event, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBirthday = event.type == CalendarEventType.birthday;
    final color = isBirthday ? Colors.pink : Colors.teal;
    final age = event.ageThisYear;

    return Dismissible(
      key: Key('event-${event.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Delete "${event.title}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) => context
          .read<CalendarEventBloc>()
          .add(CalendarEventDeleted(event.id, userId)),
      child: Card(
        child: InkWell(
          onTap: () => context.pushNamed('event-edit',
              pathParameters: {'id': event.id}),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBirthday
                        ? Icons.cake_outlined
                        : Icons.event_outlined,
                    color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600)),
                      if (isBirthday && age != null)
                        Text('Turns $age',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: color)),
                      if (!isBirthday && event.description != null)
                        Text(event.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (event.recurrence != EventRecurrence.none)
                      Icon(Icons.repeat,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5)),
                    if (event.reminderMinutes != null)
                      Icon(Icons.notifications_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5)),
                    Text(
                      DateFormat('HH:mm').format(event.startDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Draggable Task Card ───────────────────────────────────────────────────────

class _DraggableTaskCard extends StatelessWidget {
  final Task task;
  final String userId;
  const _DraggableTaskCard({required this.task, required this.userId});

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: TaskCard(task: task)),
      ),
      childWhenDragging:
          Opacity(opacity: 0.4, child: TaskCard(task: task)),
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (d) => d.data.id != task.id,
        onAcceptWithDetails: (d) {
          if (task.deadline != null) {
            context.read<CalendarBloc>().add(
                  CalendarTaskDropped(d.data, task.deadline!));
          }
        },
        builder: (context, _, __) => TaskCard(task: task),
      ),
    );
  }
}
