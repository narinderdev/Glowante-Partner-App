import 'package:flutter_bloc/flutter_bloc.dart';
import 'otp_event.dart';
import 'otp_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/utils/error_parser.dart';
import 'package:bloc_onboarding/services/user_role_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        final data = response['data'];
        final Map<String, dynamic>? user = data is Map
            ? data['user'] is Map
                ? Map<String, dynamic>.from(data['user'] as Map)
                : null
            : null;
        final String? token = data is Map ? data['token']?.toString() : null;

        if (token != null && token.isNotEmpty && user != null) {
          final prefs = await SharedPreferences.getInstance();
          final int? userId = user['id'] is int
              ? user['id'] as int
              : int.tryParse('${user['id']}');

          await prefs.setString('user_token', token);
          await prefs.setString('phone_number', event.phoneNumber);
          if (userId != null) {
            await prefs.setInt('user_id', userId);
          } else {
            await prefs.remove('user_id');
          }

          await UserRoleSession.instance.persistUserRoles(user);
          await UserRoleSession.instance.persistUserSalons(user);
          await UserRoleSession.instance.persistUserBranches(user);
          await UserRoleSession.instance.persistUserPermissions(user);
        }

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
