import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../domain/entities/task.dart';
import '../blocs/task/task_bloc.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool compact;

  const TaskCard({super.key, required this.task, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      // swipe right → complete / uncomplete
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppTheme.statusDone,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          task.status == TaskStatus.done ? Icons.undo : Icons.check_circle_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      // swipe left → delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.priorityHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) return true;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Task'),
            content:
                Text('Delete "${task.title}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.priorityHigh),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          context.read<TaskBloc>().add(TaskStatusChanged(
            task.id,
            task.status == TaskStatus.done ? TaskStatus.open : TaskStatus.done,
          ));
        } else {
          context.read<TaskBloc>().add(TaskDeleted(task.id));
        }
      },
      child: Card(
        child: InkWell(
          onTap: () => context.pushNamed('task-detail',
              pathParameters: {'id': task.id}),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion checkbox
                _PriorityCheckbox(task: task),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: task.status == TaskStatus.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.status == TaskStatus.done
                                        ? colorScheme.onSurface.withOpacity(0.5)
                                        : null,
                                  ),
                            ),
                          ),
                          // On web, swipe-to-complete is unreliable with mouse → show button
                          if (kIsWeb)
                            IconButton(
                              icon: Icon(
                                task.status == TaskStatus.done
                                    ? Icons.undo
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: task.status == TaskStatus.done
                                    ? AppTheme.statusDone.withOpacity(0.7)
                                    : AppTheme.statusDone,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              tooltip: task.status == TaskStatus.done
                                  ? 'Reopen'
                                  : 'Mark as done',
                              onPressed: () {
                                context.read<TaskBloc>().add(TaskStatusChanged(
                                  task.id,
                                  task.status == TaskStatus.done
                                      ? TaskStatus.open
                                      : TaskStatus.done,
                                ));
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.4)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Task'),
                                  content: Text(
                                      'Delete "${task.title}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.priorityHigh),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                context
                                    .read<TaskBloc>()
                                    .add(TaskDeleted(task.id));
                              }
                            },
                          ),
                        ],
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty &&
                          !compact) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (task.deadline != null)
                            _DeadlineChip(deadline: task.deadline!,
                                isOverdue: task.isOverdue),
                          _PriorityChip(priority: task.priority),
                          _StatusChip(status: task.status),
                          ...task.tags
                              .take(2)
                              .map((tag) => _TagChip(tag: tag)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityCheckbox extends StatelessWidget {
  final Task task;
  const _PriorityCheckbox({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    return GestureDetector(
      onTap: () {
        context.read<TaskBloc>().add(TaskStatusChanged(
              task.id,
              isDone ? TaskStatus.open : TaskStatus.done,
            ));
      },
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDone
                ? AppTheme.statusDone
                : _priorityColor(task.priority),
            width: 2,
          ),
          color: isDone ? AppTheme.statusDone : Colors.transparent,
        ),
        child: isDone
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.priorityHigh;
      case TaskPriority.medium:
        return AppTheme.priorityMedium;
      case TaskPriority.low:
        return AppTheme.priorityLow;
    }
  }
}

class _DeadlineChip extends StatelessWidget {
  final DateTime deadline;
  final bool isOverdue;

  const _DeadlineChip({required this.deadline, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;
    final label = isToday
        ? 'Today ${DateFormat.Hm().format(deadline)}'
        : DateFormat('MMMd · HH:mm').format(deadline);

    return _Chip(
      label: label,
      icon: Icons.schedule_outlined,
      color: isOverdue ? AppTheme.priorityHigh : AppTheme.statusInProgress,
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final labels = {
      TaskPriority.high: ('High', AppTheme.priorityHigh),
      TaskPriority.medium: ('Medium', AppTheme.priorityMedium),
      TaskPriority.low: ('Low', AppTheme.priorityLow),
    };
    final (label, color) = labels[priority]!;
    return _Chip(
        label: label, icon: Icons.flag_outlined, color: color);
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final labels = {
      TaskStatus.open: ('Open', AppTheme.statusOpen),
      TaskStatus.inProgress: ('In Progress', AppTheme.statusInProgress),
      TaskStatus.done: ('Done', AppTheme.statusDone),
    };
    final (label, color) = labels[status]!;
    return _Chip(label: label, color: color);
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: '#$tag',
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _Chip({required this.label, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
