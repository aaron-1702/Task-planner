import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/work_entry.dart';
import '../../domain/repositories/work_entry_repository.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/supabase_work_entry_datasource.dart';
import '../models/work_entry_model.dart';

@Injectable(as: WorkEntryRepository)
class WorkEntryRepositoryImpl implements WorkEntryRepository {
  final LocalDatabase _local;
  final SupabaseWorkEntryDatasource _remote;

  const WorkEntryRepositoryImpl(this._local, this._remote);

  // ── Streams ────────────────────────────────────────────────────────────────

  @override
  Stream<List<WorkEntry>> watchEntriesByUser(String userId) =>
      _local.watchWorkEntriesByUser(userId).map(_mapRows);

  @override
  Stream<List<WorkEntry>> watchEntriesInRange(
          String userId, DateTime start, DateTime end) =>
      _local.watchWorkEntriesInRange(userId, start, end).map(_mapRows);

  // ── Create ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, WorkEntry>> createEntry(WorkEntry entry) async {
    try {
      await _local.upsertWorkEntry(_toRow(entry, synced: false));
      try {
        final model = await _remote
            .upsertEntry(WorkEntryModel.fromEntity(entry));
        await _local.upsertWorkEntry(_toRow(model, synced: true));
        return Right(model);
      } catch (_) {
        // Offline – will sync later
        return Right(entry);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, WorkEntry>> updateEntry(WorkEntry entry) async {
    try {
      final updated = entry.copyWith(updatedAt: DateTime.now().toUtc());
      await _local.upsertWorkEntry(_toRow(updated, synced: false));
      try {
        final model =
            await _remote.upsertEntry(WorkEntryModel.fromEntity(updated));
        await _local.upsertWorkEntry(_toRow(model, synced: true));
        return Right(model);
      } catch (_) {
        return Right(updated);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> deleteEntry(
      String entryId, String userId) async {
    try {
      // Soft-delete locally
      final rows = await _local.watchWorkEntriesByUser(userId).first;
      final row = rows.firstWhere((r) => r.id == entryId,
          orElse: () => throw Exception('Entry not found'));
      await _local.upsertWorkEntry(
        row.copyWith(isDeleted: true, isSynced: false),
      );
      try {
        await _remote.deleteEntry(entryId, userId);
        await _local.deleteWorkEntryById(entryId);
      } catch (_) {
        // Will hard-delete on next sync
      }
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> syncFromRemote(String userId) async {
    try {
      // Push unsynced local entries first
      final unsynced = await _local.getUnsyncedWorkEntries();
      for (final row in unsynced) {
        if (row.isDeleted) {
          try {
            await _remote.deleteEntry(row.id, userId);
            await _local.deleteWorkEntryById(row.id);
          } catch (_) {}
        } else {
          try {
            await _remote.upsertEntry(WorkEntryModel.fromEntity(_fromRow(row)));
            await _local.markWorkEntrySynced(row.id);
          } catch (_) {}
        }
      }

      // Pull remote
      final remoteEntries = await _remote.getEntriesByUser(userId);
      await _local.upsertWorkEntries(
          remoteEntries.map((e) => _toRow(e, synced: true)).toList());

      // Remove local entries that no longer exist on the remote.
      // This handles deletes from other devices when the Realtime event was
      // missed (e.g. device was offline, or REPLICA IDENTITY was not FULL).
      // Only removes entries that are already synced — never touches pending
      // offline changes (isSynced=false) to avoid data loss.
      final remoteIds = remoteEntries.map((e) => e.id).toSet();
      final localRows = await _local.watchWorkEntriesByUser(userId).first;
      for (final row in localRows) {
        if (row.isSynced && !row.isDeleted && !remoteIds.contains(row.id)) {
          await _local.deleteWorkEntryById(row.id);
        }
      }

      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<WorkEntry> _mapRows(List<WorkEntriesTableData> rows) =>
      rows.map(_fromRow).toList();

  WorkEntry _fromRow(WorkEntriesTableData r) => WorkEntry(
        id: r.id,
        userId: r.userId,
        date: r.date,
        startTime: r.startTime,
        endTime: r.endTime,
        breakMinutes: r.breakMinutes,
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        isDeleted: r.isDeleted,
      );

  WorkEntriesTableData _toRow(WorkEntry e, {required bool synced}) =>
      WorkEntriesTableData(
        id: e.id,
        userId: e.userId,
        date: e.date,
        startTime: e.startTime,
        endTime: e.endTime,
        breakMinutes: e.breakMinutes,
        note: e.note,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
        isSynced: synced,
      );
}
