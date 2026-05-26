import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/errors/failures.dart';
import '../entities/learning_entry.dart';
import '../repositories/learning_entry_repository.dart';

@injectable
class WatchLearningEntriesUseCase {
  final LearningEntryRepository _repository;
  const WatchLearningEntriesUseCase(this._repository);

  Stream<List<LearningEntry>> call(String userId) =>
      _repository.watchEntriesByUser(userId);
}

@injectable
class WatchLearningEntriesInRangeUseCase {
  final LearningEntryRepository _repository;
  const WatchLearningEntriesInRangeUseCase(this._repository);

  Stream<List<LearningEntry>> call(
          String userId, DateTime start, DateTime end) =>
      _repository.watchEntriesInRange(userId, start, end);
}

@injectable
class CreateLearningEntryUseCase {
  final LearningEntryRepository _repository;
  const CreateLearningEntryUseCase(this._repository);

  Future<Either<Failure, LearningEntry>> call(LearningEntry entry) =>
      _repository.createEntry(entry);
}

@injectable
class UpdateLearningEntryUseCase {
  final LearningEntryRepository _repository;
  const UpdateLearningEntryUseCase(this._repository);

  Future<Either<Failure, LearningEntry>> call(LearningEntry entry) =>
      _repository.updateEntry(entry);
}

@injectable
class DeleteLearningEntryUseCase {
  final LearningEntryRepository _repository;
  const DeleteLearningEntryUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String entryId, String userId) =>
      _repository.deleteEntry(entryId, userId);
}

@injectable
class SyncLearningEntriesUseCase {
  final LearningEntryRepository _repository;
  const SyncLearningEntriesUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String userId) =>
      _repository.syncFromRemote(userId);
}

@injectable
class ExportLearningEntriesCsvUseCase {
  const ExportLearningEntriesCsvUseCase();

  String call(List<LearningEntry> entries) {
    final buf = StringBuffer();
    buf.writeln('Date,Topic,Start,End,Break (min),Net Hours,Note');

    for (final e in entries) {
      final net = e.learningDuration.inMinutes / 60.0;
      buf.writeln(
        '${_fmtDate(e.date)},'
        '${_esc(e.topic)},'
        '${_fmtTime(e.startTime)},'
        '${_fmtTime(e.endTime)},'
        '${e.breakMinutes},'
        '${net.toStringAsFixed(2)},'
        '${_esc(e.note ?? '')}',
      );
    }

    return buf.toString();
  }

  static String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
  }

  static String _fmtTime(DateTime d) {
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _esc(String value) => '"${value.replaceAll('"', '""')}"';
}
