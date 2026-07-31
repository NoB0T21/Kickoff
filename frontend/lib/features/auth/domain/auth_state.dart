/// Represents the authentication state of the app.
enum AuthStatus {
  /// Initial state — checking if there's an existing session.
  initial,

  /// User is authenticated and has completed onboarding.
  authenticated,

  /// User is not authenticated.
  unauthenticated,

  /// User is authenticated but hasn't completed onboarding.
  onboarding,
}

/// Holds the current auth state + any associated error.
class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
