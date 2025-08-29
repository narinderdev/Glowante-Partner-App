// auth_event.dart
abstract class AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String phoneNumber;
  AuthLoginEvent({required this.phoneNumber});
}
