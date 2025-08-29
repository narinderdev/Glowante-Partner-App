// otp_state.dart

abstract class OtpState {}

class OtpInitial extends OtpState {}

class OtpLoading extends OtpState {}

class OtpVerifySuccess extends OtpState {
  final Map<String, dynamic> response;

  OtpVerifySuccess(this.response);
}

class OtpVerifyError extends OtpState {
  final String message;

  OtpVerifyError(this.message);
}
