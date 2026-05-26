import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/learning_entry.dart';

abstract class LearningEntryRepository {
  Stream<List<LearningEntry>> watchEntriesByUser(String userId);

  Stream<List<LearningEntry>> watchEntriesInRange(
      String userId, DateTime start, DateTime end);

  Future<Either<Failure, LearningEntry>> createEntry(LearningEntry entry);
  Future<Either<Failure, LearningEntry>> updateEntry(LearningEntry entry);
  Future<Either<Failure, Unit>> deleteEntry(String entryId, String userId);

  Future<Either<Failure, Unit>> syncFromRemote(String userId);
}
