import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/otp/otp_bloc.dart';
import 'package:bloc_onboarding/bloc/home/home_bloc.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/screens/splash_screen.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import 'package:bloc_onboarding/repositories/branch_repository.dart';
import './Viewmodels/BranchViewModel.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[Firebase] Widgets binding initialised');

  await dotenv.load();
  print('[Firebase] .env loaded');

  print('[Firebase] Initialising core...');
  await Firebase.initializeApp();
  print('[Firebase] Core initialised');

  print('[Firebase] Initialising push notification service...');
  await PushNotificationService.instance.initialize();
  print('[Firebase] Push notification service ready');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        RepositoryProvider<ApiService>(create: (_) => ApiService()),
        RepositoryProvider<SalonRepository>(create: (_) => SalonRepository()),
        RepositoryProvider<BranchRepository>(create: (_) => BranchRepository()),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(context.read<ApiService>()),
        ),
        BlocProvider<OtpBloc>(
          create: (context) => OtpBloc(context.read<ApiService>()),
        ),
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
        BlocProvider<SalonListCubit>(
          create: (context) => SalonListCubit(context.read<SalonRepository>()),
        ),
        BlocProvider<CategoryCubit>(
          create: (context) => CategoryCubit(context.read<SalonRepository>()),
        ),
        ChangeNotifierProvider(create: (_) => BranchViewModel()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      ),
    );
  }
}
