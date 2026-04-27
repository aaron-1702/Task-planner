part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInWithEmail extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInWithEmail(this.email, this.password);
  @override
  List<Object> get props => [email, password];
}

class AuthSignInWithGoogle extends AuthEvent {}

class AuthSignInWithMicrosoft extends AuthEvent {}

/// Signs in directly as a local user — no credentials needed.
class AuthSignInAsLocalUser extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const AuthSignUpRequested(this.email, this.password, this.displayName);
  @override
  List<Object> get props => [email, password, displayName];
}

class AuthSignOutRequested extends AuthEvent {}

class _AuthUserChanged extends AuthEvent {
  final AppUser? user;
  const _AuthUserChanged(this.user);
  @override
  List<Object?> get props => [user];
}
