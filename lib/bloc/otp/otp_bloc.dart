// otp_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'otp_event.dart';
import 'otp_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  final ApiService apiService;

  OtpBloc(this.apiService) : super(OtpInitial()) {
    on<OtpVerifyEvent>(_onOtpVerifyEvent);
  }
  // otp_bloc.dart
void _onOtpVerifyEvent(OtpVerifyEvent event, Emitter<OtpState> emit) async {
  emit(OtpLoading());  // Emit loading state before verification

  try {
    final response = await apiService.verifyOTP(event.phoneNumber, event.otp);
    
    print('API Response: $response');  // Debugging output
    
    // Ensure success is true before emitting success state
    if (response['success'] == true) {
      print("Emitting OtpVerifySuccess: $response");
      emit(OtpVerifySuccess(response));  // Emit success state
    } else {
      emit(OtpVerifyError(response['message']));  // Emit error state
    }
  } catch (e) {
    print("Error during OTP verification: $e");
    emit(OtpVerifyError("OTP verification failed: $e"));  // Emit error state on failure
  }
}

}
