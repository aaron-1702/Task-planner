import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injectable/injectable.dart';
import 'dart:convert';

part 'local_database.g.dart';

// ─── Table Definitions ───────────────────────────────────────────────────────

class TasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get categoryId => text().nullable()();
  TextColumn get recurrenceRule => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get pomodoroCount => integer().nullable()();
  TextColumn get subtasks => text().withDefault(const Constant('[]'))(); // JSON
  BoolColumn get isSynced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class CalendarEventsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get type => text().withDefault(const Constant('event'))();
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  IntColumn get reminderMinutes => integer().nullable()();
  IntColumn get birthYear => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class UserProfilesTable extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get fcmToken => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkEntriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [TasksTable, CategoriesTable, UserProfilesTable, CalendarEventsTable, WorkEntriesTable])
@singleton
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasksTable, tasksTable.subtasks);
          }
          if (from < 3) {
            await m.createTable(calendarEventsTable);
          }
          if (from < 4) {
            await m.createTable(workEntriesTable);
          }
        },
      );

  static QueryExecutor _openConnection() {
    if (kIsWeb) {
      return driftDatabase(
        name: 'smart_task_planner',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );
    }
    return driftDatabase(name: 'smart_task_planner');
  }

  // ── Task Queries ──────────────────────────────────────────────────────────

  Stream<List<TasksTableData>> watchTasksByUser(String userId) {
    return (select(tasksTable)
          ..where((t) => Expression.and(
              [t.userId.equals(userId), t.isDeleted.equals(false)]))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<TasksTableData>> watchTasksByDate(
      String userId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(tasksTable)
          ..where((t) => Expression.and(
              [t.userId.equals(userId), t.isDeleted.equals(false)]))
          ..orderBy([(t) => OrderingTerm.asc(t.deadline)]))
        .watch()
        .map((rows) => rows
            .where((t) =>
                t.deadline != null &&
                !t.deadline!.isBefore(dayStart) &&
                t.deadline!.isBefore(dayEnd))
            .toList());
  }

  Future<List<TasksTableData>> getUnsyncedTasks() {
    return (select(tasksTable)
          ..where((t) => t.isSynced.equals(false)))
        .get();
  }

  Future<void> upsertTask(TasksTableData task) async {
    await into(tasksTable).insertOnConflictUpdate(task);
  }

  Future<void> upsertTasks(List<TasksTableData> tasks) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(tasksTable, tasks);
    });
  }

  Future<void> markTaskSynced(String taskId) async {
    await (update(tasksTable)..where((t) => t.id.equals(taskId)))
        .write(const TasksTableCompanion(isSynced: Value(true)));
  }

  Future<void> deleteTaskById(String taskId) async {
    await (delete(tasksTable)..where((t) => t.id.equals(taskId))).go();
  }

  // ── CalendarEvent Queries ─────────────────────────────────────────────────

  Stream<List<CalendarEventsTableData>> watchEventsByUser(String userId) {
    return (select(calendarEventsTable)
          ..where((e) => Expression.and(
              [e.userId.equals(userId), e.isDeleted.equals(false)]))
          ..orderBy([(e) => OrderingTerm.asc(e.startDate)]))
        .watch();
  }

  Future<void> upsertEvent(CalendarEventsTableData event) async {
    await into(calendarEventsTable).insertOnConflictUpdate(event);
  }

  Future<void> upsertEvents(List<CalendarEventsTableData> events) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(calendarEventsTable, events);
    });
  }

  Future<void> deleteEventById(String eventId) async {
    await (delete(calendarEventsTable)
          ..where((e) => e.id.equals(eventId)))
        .go();
  }

  Future<List<CalendarEventsTableData>> getUnsyncedEvents() {
    return (select(calendarEventsTable)
          ..where((e) => e.isSynced.equals(false)))
        .get();
  }

  Future<void> markEventSynced(String eventId) async {
    await (update(calendarEventsTable)
          ..where((e) => e.id.equals(eventId)))
        .write(const CalendarEventsTableCompanion(isSynced: Value(true)));
  }

  // ── Category Queries ──────────────────────────────────────────────────────

  Stream<List<CategoriesTableData>> watchCategoriesByUser(String userId) {
    return (select(categoriesTable)
          ..where((c) => c.userId.equals(userId))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<void> upsertCategory(CategoriesTableData category) async {
    await into(categoriesTable).insertOnConflictUpdate(category);
  }

  // ── WorkEntry Queries ─────────────────────────────────────────────────────

  Stream<List<WorkEntriesTableData>> watchWorkEntriesByUser(String userId) {
    return (select(workEntriesTable)
          ..where((e) => Expression.and(
              [e.userId.equals(userId), e.isDeleted.equals(false)]))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Stream<List<WorkEntriesTableData>> watchWorkEntriesInRange(
      String userId, DateTime start, DateTime end) {
    return (select(workEntriesTable)
          ..where((e) => Expression.and(
              [e.userId.equals(userId), e.isDeleted.equals(false)]))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch()
        .map((rows) => rows
            .where((e) =>
                !e.date.isBefore(start) && !e.date.isAfter(end))
            .toList());
  }

  Future<void> upsertWorkEntry(WorkEntriesTableData entry) async {
    await into(workEntriesTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertWorkEntries(List<WorkEntriesTableData> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(workEntriesTable, entries);
    });
  }

  Future<void> markWorkEntrySynced(String entryId) async {
    await (update(workEntriesTable)
          ..where((e) => e.id.equals(entryId)))
        .write(const WorkEntriesTableCompanion(isSynced: Value(true)));
  }

  Future<void> deleteWorkEntryById(String entryId) async {
    await (delete(workEntriesTable)..where((e) => e.id.equals(entryId))).go();
  }

  Future<List<WorkEntriesTableData>> getUnsyncedWorkEntries() {
    return (select(workEntriesTable)
          ..where((e) => e.isSynced.equals(false)))
        .get();
  }
}
