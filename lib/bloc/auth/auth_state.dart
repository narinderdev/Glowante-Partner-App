abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthLoginSuccess extends AuthState {
  final Map<String, dynamic> response;
  AuthLoginSuccess(this.response);
}

class AuthError extends AuthState {
  final String message;
  final String? code;
  final int? retryAfterSeconds;

  AuthError(this.message, {this.code, this.retryAfterSeconds});
}
