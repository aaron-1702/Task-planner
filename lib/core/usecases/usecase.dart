import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

abstract class UseCase<Result, Params> {
  Future<Either<Failure, Result>> call(Params params);
}

abstract class StreamUseCase<Result, Params> {
  Stream<Result> call(Params params);
}
