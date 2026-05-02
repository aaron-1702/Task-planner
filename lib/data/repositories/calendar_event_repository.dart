import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' hide DataClass;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/calendar_event.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/supabase_calendar_event_datasource.dart';
import '../models/calendar_event_model.dart';

@singleton
class CalendarEventRepository {
  final LocalDatabase _local;
  final SupabaseCalendarEventDatasource _remote;
  final _uuid = const Uuid();

  CalendarEventRepository(this._local, this._remote);

  // ── Stream ─────────────────────────────────────────────────────────────────

  Stream<List<CalendarEvent>> watchEventsByUser(String userId) {
    return _local.watchEventsByUser(userId).map(
          (rows) => rows.map(_rowToModel).toList(),
        );
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<Either<Failure, CalendarEvent>> createEvent(
      CalendarEvent event) async {
    try {
      final now = DateTime.now().toUtc();
      final model = CalendarEventModel.fromEntity(
        event.copyWith(
          id: event.id.isEmpty ? _uuid.v4() : event.id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _local.upsertEvent(_modelToRow(model, isSynced: false));

      try {
        final remote = await _remote.createEvent(model);
        await _local.upsertEvent(_modelToRow(remote, isSynced: true));
        return Right(remote);
      } catch (_) {
        return Right(model);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<Either<Failure, CalendarEvent>> updateEvent(
      CalendarEvent event) async {
    try {
      final model = CalendarEventModel.fromEntity(
          event.copyWith(updatedAt: DateTime.now().toUtc()));

      await _local.upsertEvent(_modelToRow(model, isSynced: false));

      try {
        final remote = await _remote.updateEvent(model);
        await _local.upsertEvent(_modelToRow(remote, isSynced: true));
        return Right(remote);
      } catch (_) {
        return Right(model);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<Either<Failure, Unit>> deleteEvent(String eventId,
      String userId) async {
    try {
      await _local.deleteEventById(eventId);
      try {
        await _remote.deleteEvent(eventId, userId);
      } catch (_) {}
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  Future<void> syncEvents(String userId, DateTime since) async {
    try {
      final unsynced = await _local.getUnsyncedEvents();
      for (final row in unsynced) {
        final model = _rowToModel(row);
        if (row.isDeleted) {
          await _remote.deleteEvent(row.id, row.userId);
        } else {
          await _remote.updateEvent(CalendarEventModel.fromEntity(model));
        }
        await _local.markEventSynced(row.id);
      }

      final remoteChanges = await _remote.getEventsSince(userId, since);
      if (remoteChanges.isNotEmpty) {
        await _local.upsertEvents(
          remoteChanges.map((e) => _modelToRow(e, isSynced: true)).toList(),
        );
      }
    } catch (_) {
      // Sync failure is non-fatal
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  CalendarEvent _rowToModel(CalendarEventsTableData row) {
    return CalendarEventModel(
      id: row.id,
      userId: row.userId,
      title: row.title,
      description: row.description,
      startDate: row.startDate,
      endDate: row.endDate,
      type: CalendarEventType.values.byName(row.type),
      recurrence: EventRecurrence.values.byName(row.recurrence),
      reminderMinutes: row.reminderMinutes,
      birthYear: row.birthYear,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
    );
  }

  CalendarEventsTableData _modelToRow(CalendarEventModel model,
      {required bool isSynced}) {
    return CalendarEventsTableData(
      id: model.id,
      userId: model.userId,
      title: model.title,
      description: model.description,
      startDate: model.startDate,
      endDate: model.endDate,
      type: model.type.name,
      recurrence: model.recurrence.name,
      reminderMinutes: model.reminderMinutes,
      birthYear: model.birthYear,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isDeleted: model.isDeleted,
      isSynced: isSynced,
    );
  }
}
