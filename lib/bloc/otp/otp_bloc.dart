import 'package:flutter_bloc/flutter_bloc.dart';
import 'otp_event.dart';
import 'otp_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/utils/error_parser.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  final ApiService apiService;

  OtpBloc(this.apiService) : super(OtpInitial()) {
    on<OtpVerifyEvent>(_onOtpVerifyEvent);
  }

  void _onOtpVerifyEvent(OtpVerifyEvent event, Emitter<OtpState> emit) async {
    emit(OtpLoading()); 

    try {
      final response = await apiService.verifyOTP(event.phoneNumber, event.otp);

      print('API Response: $response'); 
      if (response['success'] == true) {
        print("Emitting OtpVerifySuccess: $response");
        emit(OtpVerifySuccess(response)); 
      } else {
        final errorMessage = extractMessage(
          response,
          fallback: 'Invalid or expired OTP',
        );
        emit(OtpVerifyError(errorMessage));
      }
    } catch (e) {
      print("Error during OTP verification: $e");
      final errorMessage = extractErrorMessage(
        e,
        fallback: 'Invalid or expired OTP',
      );
      emit(OtpVerifyError(errorMessage)); 
    }
  }
}
