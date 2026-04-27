import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/auth/register_page.dart';
import '../presentation/pages/dashboard/dashboard_page.dart';
import '../presentation/pages/tasks/task_list_page.dart';
import '../presentation/pages/tasks/task_detail_page.dart';
import '../presentation/pages/tasks/task_form_page.dart';
import '../presentation/pages/calendar/calendar_page.dart';
import '../presentation/pages/settings/settings_page.dart';
import '../presentation/pages/stats/stats_page.dart';
import '../presentation/shell/main_shell.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: _GoRouterRefreshStream(),
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Main Shell (with bottom nav / side rail)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TaskListPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'task-detail',
                builder: (context, state) => TaskDetailPage(
                  taskId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const CalendarPage(),
          ),
          GoRoute(
            path: '/stats',
            name: 'stats',
            builder: (context, state) => const StatsPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),

      // Full-screen routes (outside shell)
      GoRoute(
        path: '/task-form',
        name: 'task-new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TaskFormPage(
          initialDate: state.uri.queryParameters['date'] != null
              ? DateTime.parse(state.uri.queryParameters['date']!)
              : null,
        ),
      ),
      GoRoute(
        path: '/task-edit/:id',
        name: 'task-edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TaskFormPage(
          taskId: state.pathParameters['id'],
        ),
      ),
    ],
  );
}

/// Bridges AuthBloc state changes to GoRouter's refresh mechanism.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream() {
    // Listen for auth state changes to trigger router refresh
    // In real app wire to AuthBloc stream
  }
}
