import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/task/task_bloc.dart';
import '../../core/di/injection.dart';
import '../../services/sync_service.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const _destinations = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
    (label: 'Tasks', icon: Icons.task_alt_outlined, route: '/tasks'),
    (label: 'Calendar', icon: Icons.calendar_month_outlined, route: '/calendar'),
    (label: 'Stats', icon: Icons.bar_chart_outlined, route: '/stats'),
    (label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (mounted && online != _isOnline) setState(() => _isOnline = online);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        context.read<TaskBloc>().add(
              TaskSubscriptionRequested(authState.user.id),
            );
        getIt<SyncService>().start(authState.user.id);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _destinations.indexWhere(
        (d) => location.startsWith(d.route));
    if (index != -1 && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          getIt<SyncService>().stop();
          context.go('/auth/login');
        } else if (state is AuthAuthenticated) {
          context.read<TaskBloc>().add(
                TaskSubscriptionRequested(state.user.id),
              );
          getIt<SyncService>().start(state.user.id);
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            if (isWide)
              NavigationRail(
                extended: MediaQuery.of(context).size.width >= 1024,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
                destinations: _destinations
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _isOnline ? 0.0 : 32.0,
                    color: Colors.orange.shade700,
                    child: _isOnline
                        ? null
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text('No internet connection',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: _destinations
                    .map((d) => NavigationDestination(
                          icon: Icon(d.icon),
                          label: d.label,
                        ))
                    .toList(),
              ),
        floatingActionButton: _selectedIndex <= 1
            ? FloatingActionButton.extended(
                onPressed: () => context.pushNamed('task-new'),
                icon: const Icon(Icons.add),
                label: const Text('New Task'),
              )
            : null,
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go(_destinations[index].route);
  }
}
