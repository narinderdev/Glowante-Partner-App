abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthLoginSuccess extends AuthState {
  final Map<String, dynamic> response;
  AuthLoginSuccess(this.response);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
