import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../widgets/task_card.dart';
import '../../widgets/stats_summary_card.dart';
import '../../../domain/entities/task.dart';
import '../../../config/theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        return BlocBuilder<TaskBloc, TaskState>(
          builder: (context, taskState) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(context, user?.displayName ?? user?.email ?? ''),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildGreeting(context, user?.displayName),
                      const SizedBox(height: 20),
                      _buildStatsSummary(context, taskState),
                      const SizedBox(height: 24),
                      if (taskState.overdueTasks.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          'Overdue',
                          Icons.warning_amber_rounded,
                          color: AppTheme.priorityHigh,
                          count: taskState.overdueTasks.length,
                        ),
                        const SizedBox(height: 12),
                        ...taskState.overdueTasks
                            .take(3)
                            .map((t) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: TaskCard(task: t),
                                )),
                        const SizedBox(height: 20),
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
                        ...taskState.todayTasks.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TaskCard(task: t),
                            )),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
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
            child: const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Smart Planner',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () =>
              context.read<ThemeCubit>().toggleTheme(),
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
    final dateStr =
        DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting${name != null ? ', $name' : ''}! 👋',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(dateStr,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6))),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildStatsSummary(BuildContext context, TaskState state) {
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
            value:
                '${(state.completionRate * 100).toStringAsFixed(0)}%',
            icon: Icons.trending_up_outlined,
            color: AppTheme.priorityMedium,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
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
        Icon(icon,
            size: 20, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (count != null) ...[
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.6)),
          const SizedBox(height: 12),
          Text('All clear for today!',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'No tasks due today. Enjoy your day!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}
