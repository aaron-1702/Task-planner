import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../domain/entities/task.dart';
import '../../blocs/task/task_bloc.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('Statistics',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              floating: true,
              snap: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildOverview(context, state),
                  const SizedBox(height: 24),
                  _buildCompletionChart(context, state),
                  const SizedBox(height: 24),
                  _buildPriorityBreakdown(context, state),
                  const SizedBox(height: 24),
                  _buildEisenhowerMatrix(context, state),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverview(BuildContext context, TaskState state) {
    final overdue = state.tasks.where((t) => t.isOverdue).length;
    final dueThisWeek = state.tasks
        .where((t) =>
            t.deadline != null &&
            !t.isDeleted &&
            t.status != TaskStatus.done &&
            t.deadline!.isAfter(DateTime.now()) &&
            t.deadline!.isBefore(
                DateTime.now().add(const Duration(days: 7))))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                    label: 'Total',
                    value: state.totalCount,
                    color: Theme.of(context).colorScheme.primary),
                _StatItem(
                    label: 'Done',
                    value: state.completedCount,
                    color: AppTheme.statusDone),
                _StatItem(
                    label: 'Overdue',
                    value: overdue,
                    color: AppTheme.priorityHigh),
                _StatItem(
                    label: 'Due 7d',
                    value: dueThisWeek,
                    color: AppTheme.priorityMedium),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.completionRate,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              color: AppTheme.statusDone,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${(state.completionRate * 100).toStringAsFixed(1)}% completion rate',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionChart(BuildContext context, TaskState state) {
    // Group tasks by day for the last 7 days
    final now = DateTime.now();
    final spots = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final count = state.tasks
          .where((t) =>
              t.status == TaskStatus.done &&
              t.updatedAt.year == day.year &&
              t.updatedAt.month == day.month &&
              t.updatedAt.day == day.day)
          .length;
      return FlSpot(i.toDouble(), count.toDouble());
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks Completed (Last 7 Days)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final day = now
                              .subtract(Duration(days: 6 - value.toInt()));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(DateFormat('E').format(day),
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBreakdown(
      BuildContext context, TaskState state) {
    final high = state.tasks
        .where((t) =>
            t.priority == TaskPriority.high && !t.isDeleted)
        .length;
    final medium = state.tasks
        .where((t) =>
            t.priority == TaskPriority.medium && !t.isDeleted)
        .length;
    final low = state.tasks
        .where((t) =>
            t.priority == TaskPriority.low && !t.isDeleted)
        .length;
    final total = high + medium + low;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Priority Breakdown',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (total > 0)
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          if (high > 0)
                            PieChartSectionData(
                                value: high.toDouble(),
                                color: AppTheme.priorityHigh,
                                title: '$high',
                                radius: 50),
                          if (medium > 0)
                            PieChartSectionData(
                                value: medium.toDouble(),
                                color: AppTheme.priorityMedium,
                                title: '$medium',
                                radius: 50),
                          if (low > 0)
                            PieChartSectionData(
                                value: low.toDouble(),
                                color: AppTheme.priorityLow,
                                title: '$low',
                                radius: 50),
                        ],
                        centerSpaceRadius: 20,
                      ),
                    ),
                  ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem('High', AppTheme.priorityHigh, high),
                    const SizedBox(height: 8),
                    _LegendItem('Medium', AppTheme.priorityMedium, medium),
                    const SizedBox(height: 8),
                    _LegendItem('Low', AppTheme.priorityLow, low),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEisenhowerMatrix(
      BuildContext context, TaskState state) {
    // Urgent = overdue or due today; Important = high priority
    final quadrants = {
      'Do First\n(Urgent + Important)': state.tasks
          .where((t) =>
              !t.isDeleted &&
              t.status != TaskStatus.done &&
              t.priority == TaskPriority.high &&
              (t.isOverdue || t.isDueToday))
          .length,
      'Schedule\n(Not Urgent + Important)': state.tasks
          .where((t) =>
              !t.isDeleted &&
              t.status != TaskStatus.done &&
              t.priority == TaskPriority.high &&
              !t.isOverdue &&
              !t.isDueToday)
          .length,
      'Delegate\n(Urgent + Not Important)': state.tasks
          .where((t) =>
              !t.isDeleted &&
              t.status != TaskStatus.done &&
              t.priority != TaskPriority.high &&
              (t.isOverdue || t.isDueToday))
          .length,
      'Eliminate\n(Not Urgent + Not Important)': state.tasks
          .where((t) =>
              !t.isDeleted &&
              t.status != TaskStatus.done &&
              t.priority == TaskPriority.low &&
              !t.isOverdue &&
              !t.isDueToday)
          .length,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eisenhower Matrix',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Task prioritization framework',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6))),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _MatrixCell('Do First\n(Urgent + Important)',
                    quadrants['Do First\n(Urgent + Important)']!,
                    AppTheme.priorityHigh),
                _MatrixCell('Schedule\n(Not Urgent + Important)',
                    quadrants['Schedule\n(Not Urgent + Important)']!,
                    AppTheme.statusInProgress),
                _MatrixCell('Delegate\n(Urgent + Not Important)',
                    quadrants['Delegate\n(Urgent + Not Important)']!,
                    AppTheme.priorityMedium),
                _MatrixCell('Eliminate\n(Not Urgent + Not Important)',
                    quadrants['Eliminate\n(Not Urgent + Not Important)']!,
                    AppTheme.priorityLow),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                )),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _LegendItem(this.label, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label ($count)',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MatrixCell(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color),
          ),
          Text('$count tasks',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
