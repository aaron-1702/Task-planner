// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../data/datasources/local/local_database.dart' as _i633;
import '../../data/datasources/remote/supabase_task_datasource.dart' as _i717;
import '../../data/repositories/auth_repository_impl.dart' as _i895;
import '../../data/repositories/task_repository_impl.dart' as _i337;
import '../../domain/repositories/auth_repository.dart' as _i1073;
import '../../domain/repositories/task_repository.dart' as _i250;
import '../../domain/usecases/task_usecases.dart' as _i209;
import '../../presentation/blocs/auth/auth_bloc.dart' as _i141;
import '../../presentation/blocs/calendar/calendar_bloc.dart' as _i1073;
import '../../presentation/blocs/task/task_bloc.dart' as _i812;
import '../../presentation/blocs/theme/theme_cubit.dart' as _i473;
import '../../services/notification_service.dart' as _i85;
import '../../services/sync_service.dart' as _i183;
import 'injection.dart' as _i464;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    gh.factory<_i473.ThemeCubit>(() => _i473.ThemeCubit());
    gh.singleton<_i454.SupabaseClient>(() => registerModule.supabaseClient);
    gh.singleton<_i633.LocalDatabase>(() => _i633.LocalDatabase());
    gh.singleton<_i85.NotificationService>(() => _i85.NotificationService());
    gh.factory<_i1073.AuthRepository>(
        () => _i895.AuthRepositoryImpl(gh<_i454.SupabaseClient>()));
    gh.factory<_i717.SupabaseTaskDataSource>(
        () => _i717.SupabaseTaskDataSource(gh<_i454.SupabaseClient>()));
    gh.factory<_i250.TaskRepository>(() => _i337.TaskRepositoryImpl(
          gh<_i717.SupabaseTaskDataSource>(),
          gh<_i633.LocalDatabase>(),
        ));
    gh.factory<_i141.AuthBloc>(
        () => _i141.AuthBloc(gh<_i1073.AuthRepository>()));
    gh.singleton<_i183.SyncService>(() => _i183.SyncService(
          gh<_i250.TaskRepository>(),
          gh<_i717.SupabaseTaskDataSource>(),
          gh<_i454.SupabaseClient>(),
          gh<_i633.LocalDatabase>(),
        ));
    gh.factory<_i209.CreateTaskUseCase>(
        () => _i209.CreateTaskUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i209.UpdateTaskUseCase>(
        () => _i209.UpdateTaskUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i209.DeleteTaskUseCase>(
        () => _i209.DeleteTaskUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i209.GetTasksUseCase>(
        () => _i209.GetTasksUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i209.GetTasksByDateUseCase>(
        () => _i209.GetTasksByDateUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i209.WatchTasksUseCase>(
        () => _i209.WatchTasksUseCase(gh<_i250.TaskRepository>()));
    gh.factory<_i1073.CalendarBloc>(() => _i1073.CalendarBloc(
          gh<_i209.GetTasksByDateUseCase>(),
          gh<_i209.UpdateTaskUseCase>(),
        ));
    gh.factory<_i812.TaskBloc>(() => _i812.TaskBloc(
          gh<_i209.CreateTaskUseCase>(),
          gh<_i209.UpdateTaskUseCase>(),
          gh<_i209.DeleteTaskUseCase>(),
          gh<_i209.GetTasksUseCase>(),
          gh<_i209.WatchTasksUseCase>(),
        ));
    return this;
  }
}

class _$RegisterModule extends _i464.RegisterModule {}
