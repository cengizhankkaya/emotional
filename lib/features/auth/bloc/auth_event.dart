part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

/// Firebase [authStateChanges] akışından gelen güncelleme.
class AuthStateChanged extends AuthEvent {
  final User? user;

  const AuthStateChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AnonymousLoginRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class GoogleLoginRequested extends AuthEvent {}

class AppleLoginRequested extends AuthEvent {}

class DeleteAccountRequested extends AuthEvent {}
