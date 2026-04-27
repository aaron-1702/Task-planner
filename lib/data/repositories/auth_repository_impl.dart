import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

@Injectable(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl(this._client)
      : _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          // Placeholder — replace with real OAuth client ID from Google Cloud Console
          clientId: kIsWeb
              ? 'placeholder-client-id.apps.googleusercontent.com'
              : null,
        );

  // ── Email Auth ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, AppUser>> signInWithEmail(
      String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
          email: email, password: password);
      final user = _mapUser(response.user);
      if (user == null) return const Left(AuthFailure('Sign in failed'));
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail(
      String email, String password, String displayName) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = _mapUser(response.user);
      if (user == null) return const Left(AuthFailure('Sign up failed'));

      // Create profile row (Supabase trigger also creates one, but be explicit)
      await _client.from('user_profiles').upsert({
        'id': user.id,
        'email': email,
        'display_name': displayName,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Google Auth ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const Left(AuthFailure('Google sign-in cancelled'));
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        return const Left(AuthFailure('Google auth tokens missing'));
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = _mapUser(response.user);
      if (user == null) return const Left(AuthFailure('Google sign-in failed'));
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Microsoft Auth ─────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, AppUser>> signInWithMicrosoft() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: 'smart-task-planner://auth-callback',
      );
      // The session is handled via deep link / callback
      final session = _client.auth.currentSession;
      final user = _mapUser(_client.auth.currentUser);
      if (user == null) {
        return const Left(AuthFailure('Microsoft sign-in failed'));
      }
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _client.auth.signOut();
      return const Right(unit);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  // ── Password Reset ─────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    }
  }

  // ── Profile Update ─────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, AppUser>> updateProfile(AppUser user) async {
    try {
      await _client.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': user.displayName,
        'avatar_url': user.avatarUrl,
        'fcm_token': user.fcmToken,
      });
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Getters & Streams ──────────────────────────────────────────────────────

  @override
  AppUser? getCurrentUser() => _mapUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> watchAuthState() {
    return _client.auth.onAuthStateChange
        .map((event) => _mapUser(event.session?.user));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String? ??
          user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      createdAt: user.createdAt != null
          ? DateTime.parse(user.createdAt!)
          : DateTime.now(),
    );
  }
}
