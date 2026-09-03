abstract class AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String phoneNumber;
  final String? deviceToken;
  final String purpose;
  final String? contextToken;

  AuthLoginEvent({
    required this.phoneNumber,
    this.deviceToken,
    this.purpose = 'LOGIN_OR_REGISTER',
    this.contextToken,
  });
}
