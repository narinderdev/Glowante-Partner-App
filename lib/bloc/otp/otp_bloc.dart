import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'otp_event.dart';
import 'otp_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/utils/error_parser.dart';
import 'package:bloc_onboarding/services/push_notification_service.dart';
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
      final response = await apiService.verifyOtpChallenge(
        event.challengeId,
        event.otp,
      );

      print('API Response: $response');
      if (response['success'] == true) {
        unawaited(
          PushNotificationService.instance.requestPermissionAndRegisterToken(),
        );

        final data = response['data'];
        final Map<String, dynamic>? user = data is Map
            ? data['user'] is Map
                ? Map<String, dynamic>.from(data['user'] as Map)
                : null
            : null;
        final String? token =
            data is Map ? data['accessToken']?.toString() : null;
        final String? refreshToken =
            data is Map ? data['refreshToken']?.toString() : null;

        if (token != null && token.isNotEmpty && user != null) {
          final prefs = await SharedPreferences.getInstance();
          final int? userId = user['id'] is int
              ? user['id'] as int
              : int.tryParse('${user['id']}');

          await prefs.setString('user_token', token);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs.setString('refresh_token', refreshToken);
          }
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
        emit(OtpVerifyError(errorMessage, code: response['code']?.toString()));
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
