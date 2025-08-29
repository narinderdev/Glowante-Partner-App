import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:bloc_onboarding/utils/api_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;

  AuthBloc(this.apiService) : super(AuthInitial()) {
    on<AuthLoginEvent>((event, emit) async {
      emit(AuthLoading()); // Show loading state

      try {
        // Make the API call to log in
        final response = await apiService.loginUser(event.phoneNumber);
        print("Response: $response"); // Log the response

        // Ensure the response is structured correctly
        if (response['success'] == true) {
          print("Login successful: ${response['data']}");

          final phoneNumber = response['data']['phoneNumber'];
          final otp = response['data']['otp'];

          // Check if phoneNumber and otp are valid
          if (phoneNumber != null && otp != null) {
            // Emit AuthLoginSuccess with the response data
            print("Emitting AuthLoginSuccess with phoneNumber: $phoneNumber and OTP: $otp");
            emit(AuthLoginSuccess({'phoneNumber': phoneNumber, 'otp': otp}));
          } else {
            // Log if phoneNumber or otp are missing
            print("Error: Missing phoneNumber or otp in response data");
            emit(AuthError("Login failed: Missing phoneNumber or otp"));
          }
        } else {
          // Handle case where response['success'] is false
          print("Login failed: ${response['message']}");
          emit(AuthError("Login failed: ${response['message']}"));
        }
      } catch (e, stacktrace) {
        // Log the exception and stacktrace for better debugging
        print("Error during login: $e");
        print("Stacktrace: $stacktrace");
        emit(AuthError("Login failed: $e"));
      }
    });
  }
}

