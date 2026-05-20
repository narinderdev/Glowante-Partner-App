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
        final response = await apiService.loginUser(
          event.phoneNumber,
          deviceToken: event.deviceToken,
        );

        if (response['success'] == true) {
          final data = response['data'];
          final dynamic rawPhone =
              data is Map<String, dynamic> ? data['phoneNumber'] : null;
          final String phoneNumber =
              (rawPhone is String && rawPhone.trim().isNotEmpty)
                  ? rawPhone.trim()
                  : event.phoneNumber.trim();

          emit(AuthLoginSuccess({
            'phoneNumber': phoneNumber,
            'message': extractMessage(
              response,
              fallback: 'OTP sent successfully',
            ),
          }));
        } else {
          final errorMessage =
              extractMessage(response, fallback: 'Login failed');
          emit(AuthError(errorMessage));
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
