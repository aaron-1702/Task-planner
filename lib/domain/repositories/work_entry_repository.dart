import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/work_entry.dart';

abstract class WorkEntryRepository {
  /// Real-time stream of all non-deleted entries for [userId].
  Stream<List<WorkEntry>> watchEntriesByUser(String userId);

  /// Returns entries whose [date] falls within [start]..[end] (inclusive).
  Stream<List<WorkEntry>> watchEntriesInRange(
      String userId, DateTime start, DateTime end);

  Future<Either<Failure, WorkEntry>> createEntry(WorkEntry entry);
  Future<Either<Failure, WorkEntry>> updateEntry(WorkEntry entry);
  Future<Either<Failure, Unit>> deleteEntry(String entryId, String userId);

  /// Pull latest entries from remote and persist locally.
  Future<Either<Failure, Unit>> syncFromRemote(String userId);
}
