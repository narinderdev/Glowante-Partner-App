// otp_event.dart

abstract class OtpEvent {}

class OtpVerifyEvent extends OtpEvent {
  final String challengeId;
  final String phoneNumber;
  final String otp;

  OtpVerifyEvent({
    required this.challengeId,
    required this.phoneNumber,
    required this.otp,
  });
}
