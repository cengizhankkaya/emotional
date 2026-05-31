import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/auth/services/social_auth_credentials.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthStateChanged>(_onAuthStateChanged);
    on<LoginRequested>(_onLoginRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<AppleLoginRequested>(_onAppleLoginRequested);
    on<AnonymousLoginRequested>(_onAnonymousLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);

    _authSubscription = _firebaseAuth.authStateChanges().listen((user) {
      add(AuthStateChanged(user));
    });
  }

  final FirebaseAuth _firebaseAuth;
  StreamSubscription<User?>? _authSubscription;

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthLoading) {
      return;
    }
    final user = event.user;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAnonymousLoginRequested(
    AnonymousLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _firebaseAuth.signInAnonymously();
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(
          AuthFailure(
            LocaleKeys.auth_error_anonymousFailed.tr(
              args: [LocaleKeys.auth_error_userIsNull.tr()],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_anonymousFailed.tr(
            args: [e.message ?? LocaleKeys.auth_error_authFailed.tr()],
          ),
        ),
      );
    } catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_anonymousFailed.tr(args: [e.toString()]),
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(
          AuthFailure(
            LocaleKeys.auth_error_loginFailed.tr(
              args: [LocaleKeys.auth_error_userIsNullAfterSignIn.tr()],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_loginFailed.tr(
            args: [e.message ?? LocaleKeys.auth_error_authFailed.tr()],
          ),
        ),
      );
    } catch (e) {
      emit(
        AuthFailure(LocaleKeys.auth_error_loginFailed.tr(args: [e.toString()])),
      );
    }
  }

  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await SocialAuthCredentials.googleSignInCredential();
      await _signInWithCredential(credential, emit, isApple: false);
    } on FirebaseAuthException catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_googleFailed.tr(
            args: [e.message ?? LocaleKeys.auth_error_googleAuthFailed.tr()],
          ),
        ),
      );
    } catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_googleFailed.tr(args: [e.toString()]),
        ),
      );
    }
  }

  Future<void> _onAppleLoginRequested(
    AppleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // AuthLoading, Apple sheet acikken emit edilmez.
    try {
      final userCred = await SocialAuthCredentials.signInWithApple(
        _firebaseAuth,
      );
      final user = userCred.user ?? _firebaseAuth.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(
          AuthFailure(
            LocaleKeys.auth_error_appleFailed.tr(
              args: [LocaleKeys.auth_error_userIsNull.tr()],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (SocialAuthCredentials.isAppleSignInCancelled(e)) {
        emit(AuthUnauthenticated());
        return;
      }
      if (SocialAuthCredentials.isAppleSignInTimeout(e)) {
        emit(
          AuthFailure(LocaleKeys.auth_error_appleTimeout.tr()),
        );
        return;
      }
      emit(
        AuthFailure(
          LocaleKeys.auth_error_appleFailed.tr(
            args: [e.message ?? LocaleKeys.auth_error_appleAuthFailed.tr()],
          ),
        ),
      );
    } catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_appleFailed.tr(args: [e.toString()]),
        ),
      );
    }
  }

  Future<void> _signInWithCredential(
    AuthCredential credential,
    Emitter<AuthState> emit, {
    required bool isApple,
  }) async {
    await _firebaseAuth.signInWithCredential(credential);
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(
        AuthFailure(
          (isApple
                  ? LocaleKeys.auth_error_appleFailed
                  : LocaleKeys.auth_error_googleFailed)
              .tr(args: [LocaleKeys.auth_error_userIsNull.tr()]),
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _firebaseAuth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Yerel durumu yine de temizle.
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        emit(AuthUnauthenticated());
        return;
      }

      await SocialAuthCredentials.reauthenticateCurrentUser(_firebaseAuth);
      await user.delete();

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      emit(AuthUnauthenticated());
    } on FirebaseAuthException catch (e) {
      if (SocialAuthCredentials.isAppleSignInCancelled(e)) {
        final current = _firebaseAuth.currentUser;
        emit(
          current != null ? AuthAuthenticated(current) : AuthUnauthenticated(),
        );
        return;
      }
      if (SocialAuthCredentials.isAppleSignInTimeout(e)) {
        final current = _firebaseAuth.currentUser;
        emit(
          AuthFailure(LocaleKeys.auth_error_appleTimeout.tr()),
        );
        if (current != null) {
          emit(AuthAuthenticated(current));
        } else {
          emit(AuthUnauthenticated());
        }
        return;
      }
      if (e.code == 'requires-recent-login') {
        emit(
          AuthFailure(
            LocaleKeys.auth_error_reauthRequired.tr(),
          ),
        );
        return;
      }
      emit(
        AuthFailure(
          LocaleKeys.auth_error_deleteFailed.tr(
            args: [e.message ?? LocaleKeys.auth_error_authFailed.tr()],
          ),
        ),
      );
    } catch (e) {
      emit(
        AuthFailure(
          LocaleKeys.auth_error_deleteFailed.tr(args: [e.toString()]),
        ),
      );
    }
  }
}
