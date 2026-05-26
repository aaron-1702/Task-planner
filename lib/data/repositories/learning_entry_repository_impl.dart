import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/learning_entry.dart';
import '../../domain/repositories/learning_entry_repository.dart';
import '../datasources/local/local_database.dart';
import '../datasources/remote/supabase_learning_entry_datasource.dart';
import '../models/learning_entry_model.dart';

@Injectable(as: LearningEntryRepository)
class LearningEntryRepositoryImpl implements LearningEntryRepository {
  final LocalDatabase _local;
  final SupabaseLearningEntryDatasource _remote;

  const LearningEntryRepositoryImpl(this._local, this._remote);

  @override
  Stream<List<LearningEntry>> watchEntriesByUser(String userId) =>
      _local.watchLearningEntriesByUser(userId).map(_mapRows);

  @override
  Stream<List<LearningEntry>> watchEntriesInRange(
          String userId, DateTime start, DateTime end) =>
      _local.watchLearningEntriesInRange(userId, start, end).map(_mapRows);

  @override
  Future<Either<Failure, LearningEntry>> createEntry(
      LearningEntry entry) async {
    try {
      await _local.upsertLearningEntry(_toRow(entry, synced: false));
      try {
        final model =
            await _remote.upsertEntry(LearningEntryModel.fromEntity(entry));
        await _local.upsertLearningEntry(_toRow(model, synced: true));
        return Right(model);
      } catch (_) {
        return Right(entry);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LearningEntry>> updateEntry(
      LearningEntry entry) async {
    try {
      final updated = entry.copyWith(updatedAt: DateTime.now().toUtc());
      await _local.upsertLearningEntry(_toRow(updated, synced: false));
      try {
        final model =
            await _remote.upsertEntry(LearningEntryModel.fromEntity(updated));
        await _local.upsertLearningEntry(_toRow(model, synced: true));
        return Right(model);
      } catch (_) {
        return Right(updated);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteEntry(
      String entryId, String userId) async {
    try {
      final rows = await _local.watchLearningEntriesByUser(userId).first;
      final row = rows.firstWhere(
        (r) => r.id == entryId,
        orElse: () => throw Exception('Entry not found'),
      );
      await _local.upsertLearningEntry(
        row.copyWith(isDeleted: true, isSynced: false),
      );
      try {
        await _remote.deleteEntry(entryId, userId);
        await _local.deleteLearningEntryById(entryId);
      } catch (_) {
        // Offline: hard delete will happen on a later sync
      }
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncFromRemote(String userId) async {
    try {
      final unsynced = await _local.getUnsyncedLearningEntries();
      for (final row in unsynced) {
        if (row.isDeleted) {
          try {
            await _remote.deleteEntry(row.id, userId);
            await _local.deleteLearningEntryById(row.id);
          } catch (_) {}
        } else {
          try {
            await _remote
                .upsertEntry(LearningEntryModel.fromEntity(_fromRow(row)));
            await _local.markLearningEntrySynced(row.id);
          } catch (_) {}
        }
      }

      final remoteEntries = await _remote.getEntriesByUser(userId);
      await _local.upsertLearningEntries(
        remoteEntries.map((e) => _toRow(e, synced: true)).toList(),
      );

      final remoteIds = remoteEntries.map((e) => e.id).toSet();
      final localRows = await _local.watchLearningEntriesByUser(userId).first;
      for (final row in localRows) {
        if (row.isSynced && !row.isDeleted && !remoteIds.contains(row.id)) {
          await _local.deleteLearningEntryById(row.id);
        }
      }

      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  List<LearningEntry> _mapRows(List<LearningEntriesTableData> rows) =>
      rows.map(_fromRow).toList();

  LearningEntry _fromRow(LearningEntriesTableData r) => LearningEntry(
        id: r.id,
        userId: r.userId,
        date: r.date,
        startTime: r.startTime,
        endTime: r.endTime,
        breakMinutes: r.breakMinutes,
        topic: r.topic,
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        isDeleted: r.isDeleted,
      );

  LearningEntriesTableData _toRow(LearningEntry e, {required bool synced}) =>
      LearningEntriesTableData(
        id: e.id,
        userId: e.userId,
        date: e.date,
        startTime: e.startTime,
        endTime: e.endTime,
        breakMinutes: e.breakMinutes,
        topic: e.topic,
        note: e.note,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isDeleted: e.isDeleted,
        isSynced: synced,
      );
}
