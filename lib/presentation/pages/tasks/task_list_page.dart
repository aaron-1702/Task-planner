import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/task/task_bloc.dart';
import '../../widgets/task_card.dart';
import '../../../domain/entities/task.dart';
import '../../../core/di/injection.dart';
import '../../../services/sync_service.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        // Apply filter + search query first
        var filtered = state.tasks.where((t) => !t.isDeleted).toList();
        final f = state.filter;
        if (f.priority != null) {
          filtered = filtered.where((t) => t.priority == f.priority).toList();
        }
        if (f.categoryId != null) {
          filtered = filtered.where((t) => t.categoryId == f.categoryId).toList();
        }
        if (f.query != null && f.query!.isNotEmpty) {
          final q = f.query!.toLowerCase();
          filtered = filtered
              .where((t) =>
                  t.title.toLowerCase().contains(q) ||
                  (t.description?.toLowerCase().contains(q) ?? false))
              .toList();
        }

        final open = filtered.where((t) => t.status == TaskStatus.open).toList();
        final inProgress = filtered.where((t) => t.status == TaskStatus.inProgress).toList();
        final done = filtered.where((t) => t.status == TaskStatus.done).toList();

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                floating: true,
                snap: true,
                title: const Text('Tasks',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list_outlined),
                    onPressed: () => _showFilterSheet(context, state),
                    tooltip: 'Filter',
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(100),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SearchBar(
                          controller: _searchController,
                          hintText: 'Search tasks…',
                          leading: const Icon(Icons.search),
                          onChanged: (q) {
                            context.read<TaskBloc>().add(TaskFilterChanged(
                                state.filter.copyWith(query: q)));
                          },
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                              text:
                                  'Open (${open.length})'),
                          Tab(
                              text:
                                  'In Progress (${inProgress.length})'),
                          Tab(text: 'Done (${done.length})'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _TaskList(
                  tasks: open,
                  emptyIcon: Icons.check_circle_outline,
                  emptyTitle: 'All clear!',
                  emptySubtitle: 'No open tasks – tap + to create one.',
                ),
                _TaskList(
                  tasks: inProgress,
                  emptyIcon: Icons.play_circle_outline,
                  emptyTitle: 'Nothing in progress',
                  emptySubtitle: 'Open a task and start working on it.',
                ),
                _TaskList(
                  tasks: done,
                  emptyIcon: Icons.emoji_events_outlined,
                  emptyTitle: 'No completed tasks yet',
                  emptySubtitle: 'Complete tasks to track your progress.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, TaskState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskBloc>(),
        child: _FilterSheet(currentFilter: state.filter),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _TaskList({
    required this.tasks,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'No tasks here',
    this.emptySubtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.25)),
              const SizedBox(height: 16),
              Text(emptyTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      )),
              if (emptySubtitle.isNotEmpty) ...[                const SizedBox(height: 8),
                Text(emptySubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        )),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => getIt<SyncService>().forceSync(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: tasks.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TaskCard(task: tasks[index])
              .animate()
              .fadeIn(duration: 300.ms, delay: (index * 40).ms)
              .slideX(begin: 0.05),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final TaskFilter currentFilter;
  const _FilterSheet({required this.currentFilter});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          final filter = state.filter;
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Filter Tasks',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                Text('Priority',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TaskPriority.values.map((p) {
                    final isSelected = filter.priority == p;
                    return FilterChip(
                      label: Text(p.name.capitalize()),
                      selected: isSelected,
                      onSelected: (selected) {
                        context.read<TaskBloc>().add(TaskFilterChanged(
                              filter.copyWith(
                                priority: selected ? p : null,
                              ),
                            ));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (!filter.isEmpty)
                  FilledButton.tonal(
                    onPressed: () {
                      context.read<TaskBloc>().add(
                          const TaskFilterChanged(TaskFilter()));
                      Navigator.pop(context);
                    },
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
