import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../domain/entities/task.dart';
import '../../blocs/task/task_bloc.dart';

class TaskDetailPage extends StatelessWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        final task = state.tasks.where((t) => t.id == taskId).firstOrNull;

        if (task == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(task.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.pushNamed('task-edit',
                        pathParameters: {'id': taskId}),
                  ),
                  PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: const Text(
                                'This action cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          context
                              .read<TaskBloc>()
                              .add(TaskDeleted(taskId));
                          context.pop();
                        }
                      }
                    },
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _StatusRow(task: task),
                    const SizedBox(height: 20),
                    if (task.description != null &&
                        task.description!.isNotEmpty)
                      _Section(
                        title: 'Description',
                        child: Text(task.description!,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ),
                    if (task.subtasks.isNotEmpty)
                      _Section(
                        title: 'Subtasks',
                        child: _SubtaskChecklist(task: task),
                      ),
                    _Section(
                      title: 'Details',
                      child: _DetailGrid(task: task),
                    ),
                    if (task.tags.isNotEmpty)
                      _Section(
                        title: 'Tags',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: task.tags
                              .map((t) => Chip(label: Text('#$t')))
                              .toList(),
                        ),
                      ),
                    if (task.recurrenceRule != null)
                      _Section(
                        title: 'Recurrence',
                        child: _RecurrenceInfo(
                            rule: task.recurrenceRule!),
                      ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _BottomActionBar(task: task),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Task task;
  const _StatusRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusButton(task: task),
        const Spacer(),
        if (task.deadline != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: task.isOverdue
                  ? AppTheme.priorityHigh.withOpacity(0.12)
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  task.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_outlined,
                  size: 14,
                  color: task.isOverdue
                      ? AppTheme.priorityHigh
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEE, MMMd • HH:mm')
                      .format(task.deadline!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: task.isOverdue
                        ? AppTheme.priorityHigh
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final Task task;
  const _StatusButton({required this.task});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TaskStatus>(
      segments: const [
        ButtonSegment(value: TaskStatus.open, label: Text('Open')),
        ButtonSegment(
            value: TaskStatus.inProgress, label: Text('In Progress')),
        ButtonSegment(value: TaskStatus.done, label: Text('Done')),
      ],
      selected: {task.status},
      onSelectionChanged: (set) {
        context.read<TaskBloc>().add(TaskStatusChanged(task.id, set.first));
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final Task task;
  const _DetailGrid({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DetailRow('Priority', task.priority.name.capitalize(),
                Icons.flag_outlined),
            _DetailRow(
                'Status', task.status.name.capitalize(), Icons.circle_outlined),
            if (task.estimatedMinutes != null)
              _DetailRow(
                  'Estimate',
                  '${task.estimatedMinutes}m',
                  Icons.timer_outlined),
            if (task.pomodoroCount != null)
              _DetailRow('Pomodoros', '${task.pomodoroCount} 🍅',
                  Icons.local_pizza_outlined),
            _DetailRow(
                'Created',
                DateFormat('MMMd yyyy').format(task.createdAt),
                Icons.calendar_today_outlined),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DetailRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  )),
          const Spacer(),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}

class _RecurrenceInfo extends StatelessWidget {
  final RecurrenceRule rule;
  const _RecurrenceInfo({required this.rule});

  @override
  Widget build(BuildContext context) {
    final typeLabel = {
      RecurrenceType.daily: 'Daily',
      RecurrenceType.weekly: 'Weekly',
      RecurrenceType.monthly: 'Monthly',
      RecurrenceType.custom: 'Custom',
      RecurrenceType.none: 'None',
    }[rule.type]!;

    return Row(
      children: [
        const Icon(Icons.repeat, size: 18),
        const SizedBox(width: 8),
        Text('$typeLabel (every ${rule.interval})',
            style: Theme.of(context).textTheme.bodyMedium),
        if (rule.endDate != null) ...[
          const Text(' · until '),
          Text(DateFormat('MMMd yyyy').format(rule.endDate!),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final Task task;
  const _BottomActionBar({required this.task});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            if (task.status != TaskStatus.done)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<TaskBloc>().add(
                          TaskStatusChanged(task.id, TaskStatus.done),
                        );
                    context.pop();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Done'),
                ),
              ),
            if (task.status == TaskStatus.done)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<TaskBloc>().add(
                          TaskStatusChanged(task.id, TaskStatus.open),
                        );
                  },
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Reopen'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// -- Subtask Checklist (Detail Page) -----------------------------------------

class _SubtaskChecklist extends StatelessWidget {
  final Task task;
  const _SubtaskChecklist({required this.task});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: task.subtasks.asMap().entries.map((e) {
        final subtask = e.value;
        return CheckboxListTile(
          value: subtask.isDone,
          onChanged: (value) {
            final updated = task.subtasks.map((s) {
              return s.id == subtask.id ? s.copyWith(isDone: value ?? false) : s;
            }).toList();
            context.read<TaskBloc>().add(
                  TaskUpdated(task.copyWith(
                    subtasks: updated,
                    updatedAt: DateTime.now().toUtc(),
                  )),
                );
          },
          title: Text(
            subtask.title,
            style: subtask.isDone
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}
