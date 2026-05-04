import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/errors/failures.dart';
import '../entities/work_entry.dart';
import '../repositories/work_entry_repository.dart';

// ─── Watch all entries ────────────────────────────────────────────────────────

@injectable
class WatchWorkEntriesUseCase {
  final WorkEntryRepository _repository;
  const WatchWorkEntriesUseCase(this._repository);

  Stream<List<WorkEntry>> call(String userId) =>
      _repository.watchEntriesByUser(userId);
}

// ─── Watch entries in date range ──────────────────────────────────────────────

@injectable
class WatchWorkEntriesInRangeUseCase {
  final WorkEntryRepository _repository;
  const WatchWorkEntriesInRangeUseCase(this._repository);

  Stream<List<WorkEntry>> call(String userId, DateTime start, DateTime end) =>
      _repository.watchEntriesInRange(userId, start, end);
}

// ─── Create ───────────────────────────────────────────────────────────────────

@injectable
class CreateWorkEntryUseCase {
  final WorkEntryRepository _repository;
  const CreateWorkEntryUseCase(this._repository);

  Future<Either<Failure, WorkEntry>> call(WorkEntry entry) =>
      _repository.createEntry(entry);
}

// ─── Update ───────────────────────────────────────────────────────────────────

@injectable
class UpdateWorkEntryUseCase {
  final WorkEntryRepository _repository;
  const UpdateWorkEntryUseCase(this._repository);

  Future<Either<Failure, WorkEntry>> call(WorkEntry entry) =>
      _repository.updateEntry(entry);
}

// ─── Delete ───────────────────────────────────────────────────────────────────

@injectable
class DeleteWorkEntryUseCase {
  final WorkEntryRepository _repository;
  const DeleteWorkEntryUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String entryId, String userId) =>
      _repository.deleteEntry(entryId, userId);
}

// ─── Sync from remote ─────────────────────────────────────────────────────────

@injectable
class SyncWorkEntriesUseCase {
  final WorkEntryRepository _repository;
  const SyncWorkEntriesUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String userId) =>
      _repository.syncFromRemote(userId);
}
