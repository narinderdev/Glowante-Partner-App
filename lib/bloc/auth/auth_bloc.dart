import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/utils/error_parser.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;

  AuthBloc(this.apiService) : super(AuthInitial()) {
    on<AuthLoginEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await apiService.requestOtp(
          nationalNumber: event.phoneNumber,
          purpose: event.purpose,
          contextToken: event.contextToken,
          deviceToken: event.deviceToken,
        );

        if (response['success'] == true) {
          final data = response['data'];
          final Map<String, dynamic> map =
              data is Map<String, dynamic> ? data : <String, dynamic>{};
          final String challengeId = map['challengeId']?.toString() ?? '';

          if (challengeId.isEmpty) {
            emit(AuthError(
              'Unable to start OTP verification. Please try again.',
            ));
            return;
          }

          final dynamic rawResendAfter = map['resendAfterSeconds'];
          final int? resendAfterSeconds = rawResendAfter is int
              ? rawResendAfter
              : int.tryParse(rawResendAfter?.toString() ?? '');

          emit(AuthLoginSuccess({
            'challengeId': challengeId,
            'phoneNumber': event.phoneNumber.trim(),
            'maskedPhone': map['maskedPhone']?.toString() ?? '',
            'otpExpiresAt': map['otpExpiresAt']?.toString(),
            'resendAvailableAt': map['resendAvailableAt']?.toString(),
            'retryAfterSeconds': resendAfterSeconds,
            'message': extractMessage(
              response,
              fallback: 'OTP sent successfully',
            ),
          }));
        } else {
          final errorMessage =
              extractMessage(response, fallback: 'Login failed');
          final dynamic rawRetryAfter = response['retryAfterSeconds'];
          emit(AuthError(
            errorMessage,
            code: response['code']?.toString(),
            retryAfterSeconds: rawRetryAfter is int
                ? rawRetryAfter
                : int.tryParse(rawRetryAfter?.toString() ?? ''),
          ));
        }
      } catch (e, stacktrace) {
        print("Error during login: $e");
        print("Stacktrace: $stacktrace");
        final errorMessage = extractErrorMessage(e, fallback: 'Login failed');
        emit(AuthError(errorMessage));
      }
    });
  }
}
