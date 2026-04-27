import 'package:dartz/dartz.dart';

import '../entities/app_user.dart';
import '../../core/errors/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, AppUser>> signInWithEmail(
      String email, String password);
  Future<Either<Failure, AppUser>> signInWithGoogle();
  Future<Either<Failure, AppUser>> signInWithMicrosoft();
  Future<Either<Failure, AppUser>> signUpWithEmail(
      String email, String password, String displayName);
  Future<Either<Failure, Unit>> signOut();
  Future<Either<Failure, Unit>> resetPassword(String email);
  Future<Either<Failure, AppUser>> updateProfile(AppUser user);
  AppUser? getCurrentUser();
  Stream<AppUser?> watchAuthState();
}
