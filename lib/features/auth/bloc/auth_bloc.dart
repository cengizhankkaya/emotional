import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth;

  AuthBloc({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<AnonymousLoginRequested>(_onAnonymousLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Check if user is already signed in
    final user = _firebaseAuth.currentUser;
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
      // The state change will be handled by the stream listener if we set one up,
      // but simple implementation for now: check current user after await
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

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _firebaseAuth.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      // Ignore errors during logout, we want to clear local state anyway
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: [drive.DriveApi.driveReadonlyScope],
      );
      // Wait, in v7, authenticate() throws if it aborts/fails, it shouldn't return null.
      // But let's check if we still have access to the old object. 
      // Actually v7 authenticate returns a non-null GoogleSignInAccount, or throws.


      final googleAuth = googleUser.authentication;
      final authz = await GoogleSignIn.instance.authorizationClient.authorizationForScopes([drive.DriveApi.driveReadonlyScope]);

      final authsCredential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(authsCredential);
      final user = _firebaseAuth.currentUser;

      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(
          AuthFailure(
            LocaleKeys.auth_error_googleFailed.tr(
              args: [LocaleKeys.auth_error_userIsNull.tr()],
            ),
          ),
        );
      }
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
}
