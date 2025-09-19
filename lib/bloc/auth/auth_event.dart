// auth_event.dart
abstract class AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String phoneNumber;
  final String? deviceToken;

  AuthLoginEvent({required this.phoneNumber, this.deviceToken});
}

