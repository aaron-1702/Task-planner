class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Smart Task Planner';
  static const String appVersion = '1.0.0';

  // Supabase table names
  static const String tasksTable = 'tasks';
  static const String categoriesTable = 'categories';
  static const String usersTable = 'user_profiles';
  static const String remindersTable = 'reminders';
  static const String recurringRulesTable = 'recurring_rules';

  // Supabase realtime channels
  static const String tasksChannel = 'tasks_channel';

  // SharedPreferences keys
  static const String themeKey = 'theme_mode';
  static const String onboardingKey = 'onboarding_done';
  static const String lastSyncKey = 'last_sync_at';

  // Pagination
  static const int pageSize = 30;

  // Notification IDs
  static const String notificationChannelId = 'task_reminders';
  static const String notificationChannelName = 'Task Reminders';
  static const String notificationChannelDesc =
      'Notifications for task deadlines and reminders';

  // Max values
  static const int maxTagsPerTask = 10;
  static const int maxTitleLength = 200;
  static const int maxDescriptionLength = 5000;
}

class RouteNames {
  RouteNames._();
  static const String login = 'login';
  static const String register = 'register';
  static const String dashboard = 'dashboard';
  static const String tasks = 'tasks';
  static const String taskDetail = 'task-detail';
  static const String taskNew = 'task-new';
  static const String taskEdit = 'task-edit';
  static const String calendar = 'calendar';
  static const String stats = 'stats';
  static const String settings = 'settings';
}
