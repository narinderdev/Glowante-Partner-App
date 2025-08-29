import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/otp/otp_bloc.dart';
import 'package:bloc_onboarding/bloc/home/home_bloc.dart';
import 'package:bloc_onboarding/screens/splash_screen.dart';
import 'package:bloc_onboarding/utils/api_service.dart'; // To use ApiService in BLoC
import 'package:provider/provider.dart'; // <-- Import provider package
import './Viewmodels/BranchViewModel.dart'; // <-- Import BranchViewModel

void main() async {
  // Ensure dotenv is loaded before the app starts
  await dotenv.load();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Injecting the ApiService through a provider and passing it to the BLoCs
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(ApiService()),
        ),
        BlocProvider<OtpBloc>(
          create: (_) => OtpBloc(ApiService()),
        ),
        BlocProvider<HomeBloc>(
          create: (_) => HomeBloc(),
        ),
        // Adding BranchViewModel to the providers
        ChangeNotifierProvider(
          create: (_) => BranchViewModel(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(), // Consider adding SplashScreen logic
      ),
    );
  }
}
