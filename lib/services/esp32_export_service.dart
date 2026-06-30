import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/task.dart';

class Esp32ExportService {
  static Future<void> writeTodayTasks(List<Task> tasks) async {
    if (kIsWeb) return;

    final now = DateTime.now();
    final todayTasks = tasks
        .where(
            (t) => t.isDueToday && t.status != TaskStatus.done && !t.isDeleted)
        .toList()
      ..sort((a, b) {
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }
        if (a.deadline == null && b.deadline != null) return 1;
        if (a.deadline != null && b.deadline == null) return -1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final payload = {
      'date': _ymd(now),
      'generatedAt': now.toIso8601String(),
      'count': todayTasks.length,
      'items': todayTasks
          .map((t) => {
                'title': t.title,
                'deadline': t.deadline?.toIso8601String(),
                'priority': t.priority.name,
                'status': t.status.name,
              })
          .toList(),
    };

    // Export to both locations for compatibility
    // 1. Flutter's standard location
    final supportDir = await getApplicationSupportDirectory();
    final outDir = Directory(p.join(supportDir.path, 'esp32'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final outFile = File(p.join(outDir.path, 'today_tasks.json'));
    outFile
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));

    // 2. Export to %APPDATA%\SmartTaskPlanner\esp32\ for ESP32 bridge
    final appDataPath = Platform.environment['APPDATA'];
    if (appDataPath != null && Platform.isWindows) {
      final appDataDir =
          Directory(p.join(appDataPath, 'SmartTaskPlanner', 'esp32'));
      if (!appDataDir.existsSync()) {
        appDataDir.createSync(recursive: true);
      }
      final appDataFile = File(p.join(appDataDir.path, 'today_tasks.json'));
      appDataFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(payload));
    }
  }

  static String _ymd(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
