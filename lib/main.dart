// import 'dart:async';
// import 'dart:ui';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:provider/provider.dart';
// import './services/network_listener.dart';
// import './services/language_listener.dart';
// import './screens/splash_screen.dart';

// import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
// import 'package:bloc_onboarding/bloc/otp/otp_bloc.dart';
// import 'package:bloc_onboarding/bloc/home/home_bloc.dart';
// import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
// import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
// import 'package:bloc_onboarding/utils/api_service.dart';
// import 'package:bloc_onboarding/repositories/salon_repository.dart';
// import 'package:bloc_onboarding/repositories/branch_repository.dart';
// import './Viewmodels/BranchViewModel.dart';
// import 'services/push_notification_service.dart';

// Future<void> main() async {
//   await runZonedGuarded<Future<void>>(() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     final startupLogger = _StartupLogger();
//     startupLogger.log('[Startup] Widgets binding initialised');

//     await dotenv.load();
//     startupLogger.log('[Startup] .env loaded');

//     startupLogger.log('[Startup] Initialising Firebase core...');
//     await Firebase.initializeApp();
//     startupLogger.log('[Startup] Firebase core initialised');

//     final crashlyticsConfig = await _configureCrashlytics();
//     startupLogger.attachCrashlytics(crashlyticsConfig.instance);
//     final collectionStatus =
//         crashlyticsConfig.collectionEnabled ? 'enabled' : 'disabled';
//     final overrideSuffix = crashlyticsConfig.forceEnabled
//         ? ' (forced via ENABLE_CRASHLYTICS_DEBUG)'
//         : '';
//     startupLogger.log(
//         '[Crashlytics] Crashlytics configured (collection $collectionStatus$overrideSuffix)');

//     startupLogger.log('[Startup] Initialising push notification service...');
//     await PushNotificationService.instance.initialize();
//     startupLogger.log('[Startup] Push notification service ready');

//     NetworkManager.initialize();
//     startupLogger.log('[Startup] Network listener initialised');

//     runApp(const MyApp());
//   }, (error, stack) {
//     FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
//   });
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         RepositoryProvider<ApiService>(create: (_) => ApiService()),
//         RepositoryProvider<SalonRepository>(create: (_) => SalonRepository()),
//         RepositoryProvider<BranchRepository>(create: (_) => BranchRepository()),
//         BlocProvider<AuthBloc>(
//             create: (context) => AuthBloc(context.read<ApiService>())),
//         BlocProvider<OtpBloc>(
//             create: (context) => OtpBloc(context.read<ApiService>())),
//         BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
//         BlocProvider<SalonListCubit>(
//             create: (context) =>
//                 SalonListCubit(context.read<SalonRepository>())),
//         BlocProvider<CategoryCubit>(
//             create: (context) =>
//                 CategoryCubit(context.read<SalonRepository>())),
//         ChangeNotifierProvider(create: (_) => BranchViewModel()),

//         // Language listener
//         ChangeNotifierProvider(create: (_) => LanguageListener()),
//       ],
//       builder: (context, child) {
//         final langListener = Provider.of<LanguageListener>(context);

//         return MaterialApp(
//           debugShowCheckedModeBanner: false,
//           locale: langListener.currentLocale,
//           supportedLocales: const [
//             Locale('en'),
//             Locale('hi'),
//           ],
//           localizationsDelegates: const [
//             GlobalMaterialLocalizations.delegate,
//             GlobalWidgetsLocalizations.delegate,
//             GlobalCupertinoLocalizations.delegate,
//             // Add your custom translations if any
//             // AppTranslations.delegate,
//           ],
//           builder: (context, child) => CrashlyticsDebugOverlay(
//             child: NetworkListener(
//               child: child ?? const SizedBox.shrink(),
//             ),
//           ),
//           home: const SplashScreen(),
//         );
//       },
//     );
//   }
// }

// class CrashlyticsDebugOverlay extends StatelessWidget {
//   const CrashlyticsDebugOverlay({required this.child, super.key});

//   final Widget child;

//   @override
//   Widget build(BuildContext context) {
//     if (kReleaseMode) {
//       return child;
//     }

//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         child,
//         const Positioned(
//           right: 16,
//           bottom: 16,
//           child: SafeArea(
//             child: _CrashlyticsDebugButton(),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _CrashlyticsDebugButton extends StatefulWidget {
//   const _CrashlyticsDebugButton();

//   @override
//   State<_CrashlyticsDebugButton> createState() =>
//       _CrashlyticsDebugButtonState();
// }

// class _CrashlyticsDebugButtonState extends State<_CrashlyticsDebugButton> {
//   bool _isSending = false;

//   Future<void> _sendPing() async {
//     if (_isSending) {
//       return;
//     }
//     setState(() => _isSending = true);

//     final crashlytics = FirebaseCrashlytics.instance;
//     if (kDebugMode) {
//       await crashlytics.setCrashlyticsCollectionEnabled(true);
//     }

//     final timestamp = DateTime.now().toIso8601String();
//     crashlytics.log('[DebugButton] Manual ping at $timestamp');
//     await crashlytics.recordError(
//       Exception('Manual Crashlytics ping'),
//       StackTrace.current,
//       reason: 'Manual Crashlytics ping triggered from in-app debug button',
//       fatal: false,
//     );

//     if (mounted) {
//       setState(() => _isSending = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Crashlytics ping sent ($timestamp)')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       elevation: 6,
//       borderRadius: BorderRadius.circular(999),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: _isSending ? null : _sendPing,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           color: Colors.redAccent,
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(_isSending ? Icons.hourglass_top : Icons.bug_report,
//                   color: Colors.white),
//               const SizedBox(width: 8),
//               Text(
//                 _isSending ? 'Sending...' : 'Ping Crashlytics',
//                 style: const TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// Future<
//     ({
//       FirebaseCrashlytics instance,
//       bool collectionEnabled,
//       bool forceEnabled
//     })> _configureCrashlytics() async {
//   final crashlytics = FirebaseCrashlytics.instance;
//   final forceEnabledInDebug =
//       (dotenv.env['ENABLE_CRASHLYTICS_DEBUG'] ?? '').toLowerCase() == 'true';
//   final collectionEnabled = !kDebugMode || forceEnabledInDebug;

//   await crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);
//   await crashlytics.setUserIdentifier('developer@glowante.com');
//   await crashlytics.setCustomKey(
//       'build_mode', kDebugMode ? 'debug' : 'release');
//   if (forceEnabledInDebug && kDebugMode) {
//     await crashlytics.setCustomKey(
//         'debug_override', 'ENABLE_CRASHLYTICS_DEBUG=true');
//   }

//   final FlutterExceptionHandler? originalOnError = FlutterError.onError;
//   FlutterError.onError = (FlutterErrorDetails details) {
//     originalOnError?.call(details);
//     crashlytics.recordFlutterFatalError(details);
//   };

//   PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
//     crashlytics.recordError(error, stack, fatal: true);
//     return true;
//   };

//   return (
//     instance: crashlytics,
//     collectionEnabled: collectionEnabled,
//     forceEnabled: forceEnabledInDebug && kDebugMode,
//   );
// }

// class _StartupLogger {
//   FirebaseCrashlytics? _crashlytics;

//   void attachCrashlytics(FirebaseCrashlytics crashlytics) {
//     _crashlytics = crashlytics;
//   }

//   void log(String message) {
//     debugPrint(message);
//     _crashlytics?.log(message);
//   }
// }

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import './services/network_listener.dart';
import './services/language_listener.dart';
import './screens/splash_screen.dart';

import 'package:bloc_onboarding/bloc/auth/auth_bloc.dart';
import 'package:bloc_onboarding/bloc/otp/otp_bloc.dart';
import 'package:bloc_onboarding/bloc/home/home_bloc.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/utils/api_service.dart';
import 'package:bloc_onboarding/repositories/salon_repository.dart';
import 'package:bloc_onboarding/repositories/branch_repository.dart';
import './Viewmodels/BranchViewModel.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final startupLogger = _StartupLogger();
    startupLogger.log('[Startup] Widgets binding initialised');

    await dotenv.load();
    startupLogger.log('[Startup] .env loaded');

    startupLogger.log('[Startup] Initialising Firebase core...');
    await Firebase.initializeApp();
    startupLogger.log('[Startup] Firebase core initialised');

    final crashlytics = await _configureCrashlytics();
    startupLogger.attachCrashlytics(crashlytics);
    startupLogger.log('[Crashlytics] Crashlytics configured (collection ${kDebugMode ? 'disabled in debug' : 'enabled'})');

    startupLogger.log('[Startup] Initialising push notification service...');
    await PushNotificationService.instance.initialize();
    startupLogger.log('[Startup] Push notification service ready');

    NetworkManager.initialize();
    startupLogger.log('[Startup] Network listener initialised');

    runApp(const MyApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
        BlocProvider<AuthBloc>(create: (context) => AuthBloc(context.read<ApiService>())),
        BlocProvider<OtpBloc>(create: (context) => OtpBloc(context.read<ApiService>())),
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
        BlocProvider<SalonListCubit>(create: (context) => SalonListCubit(context.read<SalonRepository>())),
        BlocProvider<CategoryCubit>(create: (context) => CategoryCubit(context.read<SalonRepository>())),
        ChangeNotifierProvider(create: (_) => BranchViewModel()),

        // Language listener
        ChangeNotifierProvider(create: (_) => LanguageListener()),
      ],
      builder: (context, child) {
        final langListener = Provider.of<LanguageListener>(context);

return MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: langListener.currentLocale,
  supportedLocales: const [
    Locale('en'),
    Locale('hi'),
  ],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    // Add your custom translations if any
    // AppTranslations.delegate,
  ],
  builder: (context, child) => NetworkListener(
    child: child ?? const SizedBox.shrink(),
  ),
  home: const SplashScreen(),
);

      },
    );
  }
}

Future<FirebaseCrashlytics> _configureCrashlytics() async {
  final crashlytics = FirebaseCrashlytics.instance;
  final collectionEnabled = !kDebugMode;

  await crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);
  await crashlytics.setUserIdentifier('developer@glowante.com');
  await crashlytics.setCustomKey('build_mode', kDebugMode ? 'debug' : 'release');

  final FlutterExceptionHandler? originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    originalOnError?.call(details);
    crashlytics.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  return crashlytics;
}

class _StartupLogger {
  FirebaseCrashlytics? _crashlytics;

  void attachCrashlytics(FirebaseCrashlytics crashlytics) {
    _crashlytics = crashlytics;
  }

  void log(String message) {
    debugPrint(message);
    _crashlytics?.log(message);
  }
}
