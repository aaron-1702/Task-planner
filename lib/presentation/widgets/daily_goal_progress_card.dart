import 'package:flutter/material.dart';

import '../blocs/daily_goal/daily_goal_cubit.dart';

class DailyGoalProgressCard extends StatelessWidget {
  final String title;
  final String dateLabel;
  final List<DailyGoalForDate> goals;
  final int completedCount;
  final double progress;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final ValueChanged<DailyGoalForDate>? onGoalChanged;

  const DailyGoalProgressCard({
    super.key,
    required this.title,
    required this.dateLabel,
    required this.goals,
    required this.completedCount,
    required this.progress,
    this.onActionPressed,
    this.actionLabel,
    this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressValue = progress.clamp(0, 1).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ),
                ),
                if (onActionPressed != null && actionLabel != null)
                  TextButton(
                    onPressed: onActionPressed,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (goals.isEmpty) ...[
              Text(
                'No daily goals have been set yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Create a short recurring checklist for the things you want to complete every day.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ] else ...[
              Text(
                '$completedCount / ${goals.length} completed today',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                completedCount == goals.length
                    ? 'All daily goals are done for today.'
                    : '${goals.length - completedCount} still open today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: progressValue,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 14),
              ...goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DailyGoalTile(
                    goal: goal,
                    onChanged: onGoalChanged,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyGoalTile extends StatelessWidget {
  final DailyGoalForDate goal;
  final ValueChanged<DailyGoalForDate>? onChanged;

  const _DailyGoalTile({
    required this.goal,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onChanged == null
            ? null
            : () => onChanged!(
                  DailyGoalForDate(
                    id: goal.id,
                    title: goal.title,
                    isCompleted: !goal.isCompleted,
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Checkbox(
                value: goal.isCompleted,
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged!(
                          DailyGoalForDate(
                            id: goal.id,
                            title: goal.title,
                            isCompleted: value ?? false,
                          ),
                        ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: goal.isCompleted
                            ? colorScheme.onSurface.withValues(alpha: 0.55)
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}