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
      final phoneNumber = response['data']['phoneNumber'];
      final otp = response['data']['otp'];

      if (phoneNumber != null && otp != null) {
        emit(AuthLoginSuccess({'phoneNumber': phoneNumber, 'otp': otp}));
      } else {
        emit(AuthError("Login failed: Missing phoneNumber or otp"));
      }
    } else {
      final errorMessage = extractMessage(response, fallback: 'Login failed');
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
