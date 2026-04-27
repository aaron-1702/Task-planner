import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/task/task_bloc.dart';
import '../../widgets/task_card.dart';
import '../../../domain/entities/task.dart';

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
        final open = state.tasks
            .where((t) => t.status == TaskStatus.open && !t.isDeleted)
            .toList();
        final inProgress = state.tasks
            .where(
                (t) => t.status == TaskStatus.inProgress && !t.isDeleted)
            .toList();
        final done = state.tasks
            .where((t) => t.status == TaskStatus.done && !t.isDeleted)
            .toList();

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
                _TaskList(tasks: open),
                _TaskList(tasks: inProgress),
                _TaskList(tasks: done),
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
  const _TaskList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No tasks here',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: tasks.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TaskCard(task: tasks[index])
            .animate()
            .fadeIn(duration: 300.ms, delay: (index * 40).ms)
            .slideX(begin: 0.05),
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
      builder: (context, scrollController) => SingleChildScrollView(
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
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant,
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
                final isSelected = currentFilter.priority == p;
                return FilterChip(
                  label: Text(p.name.capitalize()),
                  selected: isSelected,
                  onSelected: (selected) {
                    context.read<TaskBloc>().add(TaskFilterChanged(
                          currentFilter.copyWith(
                            priority: selected ? p : null,
                          ),
                        ));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (currentFilter.priority != null ||
                currentFilter.categoryId != null)
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
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
