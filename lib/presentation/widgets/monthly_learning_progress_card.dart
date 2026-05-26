import 'package:flutter/material.dart';

class MonthlyLearningProgressCard extends StatelessWidget {
  final String title;
  final String monthLabel;
  final Duration learned;
  final Duration goal;
  final Duration remaining;
  final double progress;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const MonthlyLearningProgressCard({
    super.key,
    required this.title,
    required this.monthLabel,
    required this.learned,
    required this.goal,
    required this.remaining,
    required this.progress,
    this.onActionPressed,
    this.actionLabel,
  });

  bool get _hasGoal => goal.inMinutes > 0;

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
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: colorScheme.onTertiaryContainer,
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
                        monthLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.65),
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
            if (_hasGoal) ...[
              Text(
                '${_formatDuration(learned)} / ${_formatDuration(goal)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                remaining.inMinutes > 0
                    ? '${_formatDuration(remaining)} remaining this month'
                    : 'Monthly goal reached',
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
              const SizedBox(height: 10),
              Text(
                '${(progressValue * 100).toStringAsFixed(0)}% of monthly goal completed',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ] else ...[
              Text(
                'No monthly learning goal has been set yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Set a target in the study timer to track your progress here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }
}