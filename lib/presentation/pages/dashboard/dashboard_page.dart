import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/daily_goal/daily_goal_cubit.dart';
import '../../blocs/learning_goal/learning_goal_cubit.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../blocs/work_goal/work_goal_cubit.dart';
import '../../widgets/daily_goal_progress_card.dart';
import '../../widgets/monthly_learning_progress_card.dart';
import '../../widgets/stats_summary_card.dart';
import '../../widgets/task_card.dart';
import '../../../config/theme.dart';
import '../../../core/di/injection.dart';
import '../../../services/sync_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        return BlocBuilder<TaskBloc, TaskState>(
          builder: (context, taskState) {
            return RefreshIndicator(
              onRefresh: () => getIt<SyncService>().forceSync(),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context, user?.displayName ?? user?.email ?? ''),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: _buildHeroSection(
                        context,
                        user?.displayName,
                        taskState,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      child: _buildOverviewMetrics(context, taskState),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTaskStream(context, taskState),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildSidePanel(context, taskState),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTaskStream(context, taskState),
                              const SizedBox(height: 20),
                              _buildSidePanel(context, taskState),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String userName) {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Smart Planner',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          icon: const Icon(Icons.brightness_6_outlined),
          tooltip: 'Toggle theme',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context, String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting${name != null ? ', $name' : ''}!',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
              ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildHeroSection(
    BuildContext context,
    String? name,
    TaskState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final openTasks = state.totalCount - state.completedCount;
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(context, name),
              const SizedBox(height: 14),
              Text(
                'You have $openTasks open tasks, ${state.todayTasks.length} due today and ${state.overdueTasks.length} overdue.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    context,
                    icon: Icons.today_outlined,
                    label: dateStr,
                  ),
                  _buildStatusChip(
                    context,
                    icon: Icons.warning_amber_rounded,
                    label: '${state.overdueTasks.length} overdue',
                  ),
                  _buildStatusChip(
                    context,
                    icon: Icons.check_circle_outline,
                    label: '${state.completedCount} completed',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.goNamed('task-new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.goNamed('tasks'),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Open tasks'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08);
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics(BuildContext context, TaskState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: StatsSummaryCard(
                  title: 'Total',
                  value: state.totalCount.toString(),
                  icon: Icons.list_alt_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsSummaryCard(
                  title: 'Done',
                  value: state.completedCount.toString(),
                  icon: Icons.check_circle_outline,
                  color: AppTheme.statusDone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsSummaryCard(
                  title: 'Progress',
                  value: '${(state.completionRate * 100).toStringAsFixed(0)}%',
                  icon: Icons.trending_up_outlined,
                  color: AppTheme.priorityMedium,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
        }

        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: StatsSummaryCard(
                title: 'Total',
                value: state.totalCount.toString(),
                icon: Icons.list_alt_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatsSummaryCard(
                title: 'Done',
                value: state.completedCount.toString(),
                icon: Icons.check_circle_outline,
                color: AppTheme.statusDone,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: StatsSummaryCard(
                title: 'Progress',
                value: '${(state.completionRate * 100).toStringAsFixed(0)}%',
                icon: Icons.trending_up_outlined,
                color: AppTheme.priorityMedium,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
      },
    );
  }

  Widget _buildTaskStream(BuildContext context, TaskState taskState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (taskState.overdueTasks.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Overdue',
            Icons.warning_amber_rounded,
            color: AppTheme.priorityHigh,
            count: taskState.overdueTasks.length,
          ),
          const SizedBox(height: 12),
          ...taskState.overdueTasks.take(3).map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskCard(task: task),
                ),
              ),
          const SizedBox(height: 18),
        ],
        _buildSectionHeader(
          context,
          "Today's Tasks",
          Icons.today_outlined,
          count: taskState.todayTasks.length,
        ),
        const SizedBox(height: 12),
        if (taskState.todayTasks.isEmpty)
          _buildEmptyDay(context)
        else
          ...taskState.todayTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TaskCard(task: task),
            ),
          ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context, TaskState taskState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDailyGoalSummary(context),
        const SizedBox(height: 12),
        _buildWorkGoalSummary(context),
        const SizedBox(height: 12),
        _buildLearningGoalSummary(context),
        const SizedBox(height: 12),
        _buildInsightCard(context, taskState),
        const SizedBox(height: 12),
        _buildQuickActionsCard(context),
      ],
    );
  }

  Widget _buildDailyGoalSummary(BuildContext context) {
    final today = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(today);

    return BlocBuilder<DailyGoalCubit, DailyGoalState>(
      builder: (context, state) {
        final goals = state.goalsForDate(today);

        return DailyGoalProgressCard(
          title: 'Daily goals',
          dateLabel: dateLabel,
          goals: goals,
          completedCount: state.completedCountForDate(today),
          progress: state.progressForDate(today),
          actionLabel: goals.isEmpty ? 'Set goals' : 'Edit goals',
          onActionPressed: () => _showDailyGoalEditor(context),
          onGoalChanged: (goal) {
            context.read<DailyGoalCubit>().toggleGoalCompletion(
                  date: today,
                  goalId: goal.id,
                  isCompleted: goal.isCompleted,
                );
          },
        ).animate().fadeIn(duration: 400.ms, delay: 120.ms);
      },
    );
  }

  Widget _buildWorkGoalSummary(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    return BlocBuilder<WorkGoalCubit, WorkGoalState>(
      builder: (context, state) {
        final goal = state.goalForMonth(now);
        final worked = state.workedForMonth(now);
        final remaining = state.remainingForMonth(now);
        final progress = state.progressForMonth(now);

        return MonthlyLearningProgressCard(
          title: 'Monthly work goal',
          monthLabel: monthLabel,
          learned: worked,
          goal: goal,
          remaining: remaining,
          progress: progress,
          actionLabel: state.hasGoalForMonth(now) ? 'Edit goal' : 'Set goal',
          onActionPressed: () => context.go('/worklog'),
        ).animate().fadeIn(duration: 400.ms, delay: 140.ms);
      },
    );
  }

  Widget _buildLearningGoalSummary(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    return BlocBuilder<LearningGoalCubit, LearningGoalState>(
      builder: (context, state) {
        final goal = state.goalForMonth(now);
        final learned = state.learnedForMonth(now);
        final remaining = state.remainingForMonth(now);
        final progress = state.progressForMonth(now);

        return MonthlyLearningProgressCard(
          title: 'Monthly learning goal',
          monthLabel: monthLabel,
          learned: learned,
          goal: goal,
          remaining: remaining,
          progress: progress,
          actionLabel: state.hasGoalForMonth(now) ? 'Edit goal' : 'Set goal',
          onActionPressed: () => context.go('/learninglog'),
        ).animate().fadeIn(duration: 400.ms, delay: 180.ms);
      },
    );
  }

  Future<void> _showDailyGoalEditor(BuildContext context) async {
    final existingTitles = context
        .read<DailyGoalCubit>()
        .state
        .templates
        .map((template) => template.title)
        .toList(growable: false);
    final controllers = (existingTitles.isEmpty ? [''] : existingTitles)
        .map(TextEditingController.new)
        .toList(growable: false);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Daily goals'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set the recurring checklist you want to complete each day.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(controllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controllers[index],
                                  autofocus: index == 0 && existingTitles.isEmpty,
                                  decoration: InputDecoration(
                                    labelText: 'Goal ${index + 1}',
                                    hintText: 'Drink water, review tasks, workout...',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: controllers.length == 1
                                    ? null
                                    : () => setDialogState(() {
                                          controllers.removeAt(index).dispose();
                                        }),
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove goal',
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () => setDialogState(() {
                          controllers.add(TextEditingController());
                        }),
                        icon: const Icon(Icons.add),
                        label: const Text('Add goal'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final values = controllers
                        .map((controller) => controller.text.trim())
                        .where((value) => value.isNotEmpty)
                        .toList(growable: false);
                    Navigator.of(dialogContext).pop(values);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in controllers) {
      controller.dispose();
    }

    if (!context.mounted || result == null) return;
    await context.read<DailyGoalCubit>().setGoals(result);
  }

  Widget _buildInsightCard(BuildContext context, TaskState taskState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today at a glance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: 'Open',
                    value: (taskState.totalCount - taskState.completedCount)
                        .toString(),
                    icon: Icons.radio_button_unchecked,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: 'Due today',
                    value: taskState.todayTasks.length.toString(),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: 'Overdue',
                    value: taskState.overdueTasks.length.toString(),
                    icon: Icons.warning_amber_rounded,
                    accent: AppTheme.priorityHigh,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: 'Done',
                    value: taskState.completedCount.toString(),
                    icon: Icons.check_circle_outline,
                    accent: AppTheme.statusDone,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accent ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.add_task_outlined,
              title: 'Create task',
              subtitle: 'Add a new item to your list',
              onTap: () => context.goNamed('task-new'),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.work_outline,
              title: 'Work log',
              subtitle: 'Track monthly work progress',
              onTap: () => context.goNamed('worklog'),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.school_outlined,
              title: 'Learning log',
              subtitle: 'Update study time goals',
              onTap: () => context.goNamed('learninglog'),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.calendar_month_outlined,
              title: 'Calendar',
              subtitle: 'See your planned events',
              onTap: () => context.goNamed('calendar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    Color? color,
    int? count,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (count != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyDay(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'All clear for today!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'No tasks due today. Enjoy your day!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
