import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'core/di/injection.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/calendar_event/cal_event_bloc.dart';
import 'presentation/blocs/task/task_bloc.dart';
import 'presentation/blocs/calendar/calendar_bloc.dart';
import 'presentation/blocs/theme/theme_cubit.dart';

class SmartTaskPlannerApp extends StatefulWidget {
  const SmartTaskPlannerApp({super.key});

  @override
  State<SmartTaskPlannerApp> createState() => _SmartTaskPlannerAppState();
}

class _SmartTaskPlannerAppState extends State<SmartTaskPlannerApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());
    _router = AppRouter.createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => getIt<TaskBloc>()),
        BlocProvider(create: (_) => getIt<CalendarBloc>()),
        BlocProvider(create: (_) => getIt<CalendarEventBloc>()),
        BlocProvider(create: (_) => getIt<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'Smart Task Planner',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
