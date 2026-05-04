import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + landscape on mobile, free on desktop
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Firebase (for FCM push notifications)
  // On web without a real firebase config, this will fail gracefully.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase not configured yet — push notifications unavailable
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://pcsngbgxkristsqexgkw.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjc25nYmd4a3Jpc3RzcWV4Z2t3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczODIyMTMsImV4cCI6MjA5Mjk1ODIxM30.UBwpVsI_1xWVE5xcfwY7wXWWvd3PuMa9x4EYz8c9oZY',
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Setup dependency injection
  configureDependencies();

  // Initialize local notifications
  await getIt<NotificationService>().initialize();

  runApp(const SmartTaskPlannerApp());
}
