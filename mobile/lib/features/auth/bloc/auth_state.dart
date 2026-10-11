import 'package:equatable/equatable.dart';
import 'package:field_notes/features/auth/data/auth_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.sessionExpired = false,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// True while a login/register request is running (button spinner).
  final bool isLoading;

  /// Shown once by the UI, cleared on the next event.
  final String? errorMessage;

  /// Lets the login screen explain why the user was sent back.
  final bool sessionExpired;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? sessionExpired,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }

  @override
  List<Object?> get props => [status, user, isLoading, errorMessage, sessionExpired];
}