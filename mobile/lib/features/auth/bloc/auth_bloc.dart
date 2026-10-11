import 'package:field_notes/core/network/api_exception.dart';
import 'package:field_notes/features/auth/data/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final user = await _repository.restoreSession();
    emit(user == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, user: user));
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) {
    return _authenticate(
      emit,
          () => _repository.login(email: event.email.trim(), password: event.password),
    );
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) {
    return _authenticate(
      emit,
          () => _repository.register(
        name: event.name.trim(),
        email: event.email.trim(),
        password: event.password,
      ),
    );
  }

  /// Shared by login and register: spinner -> success or readable error.
  Future<void> _authenticate(Emitter<AuthState> emit, Future Function() action) async {
    emit(state.copyWith(isLoading: true, clearError: true, sessionExpired: false));
    try {
      final user = await action();
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Something went wrong'));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) async {
    // Only the token is dropped. Local data is kept so unsynced work is not lost;
    // the same user logging in again continues where they stopped.
    await _repository.expireSession();
    emit(const AuthState(status: AuthStatus.unauthenticated, sessionExpired: true));
  }
}