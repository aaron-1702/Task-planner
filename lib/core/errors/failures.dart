import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local data error']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation error']);
}

class ConflictFailure extends Failure {
  final Map<String, dynamic> serverVersion;
  final Map<String, dynamic> localVersion;

  const ConflictFailure(
    this.serverVersion,
    this.localVersion, [
    String message = 'Conflict detected',
  ]) : super(message);

  @override
  List<Object> get props => [message, serverVersion, localVersion];
}
