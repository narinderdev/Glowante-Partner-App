// import 'dart:async';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';

// /// Handles network monitoring and provides a stream of connectivity changes.
// class NetworkManager {
//   static final NetworkManager _instance = NetworkManager._internal();
//   factory NetworkManager() => _instance;
//   NetworkManager._internal();

//   static final StreamController<bool> _networkController =
//       StreamController<bool>.broadcast();

//   static Stream<bool> get networkStatusStream => _networkController.stream;
//   static StreamSubscription<ConnectivityResult>? _subscription;

//   /// Initialize connectivity listener
//   static void initialize() {
//     print("[NetworkManager] Initializing network listener...");
//     final Connectivity connectivity = Connectivity();

//     // Initial check
//     connectivity.checkConnectivity().then((result) {
//       final isConnected = result != ConnectivityResult.none;
//       print("[NetworkManager] Initial connectivity: $result (connected: $isConnected)");
//       _networkController.add(isConnected);
//     });

//     // Listen for changes
//     _subscription = connectivity.onConnectivityChanged.listen((result) {
//       final isConnected = result != ConnectivityResult.none;
//       print("[NetworkManager] Connectivity changed: $result (connected: $isConnected)");
//       _networkController.add(isConnected);
//     });
//   }

//   static void dispose() {
//     print("[NetworkManager] Disposing listener...");
//     _subscription?.cancel();
//     _networkController.close();
//   }
// }

// /// Widget to listen for internet connection and show UI feedback.
// class NetworkListener extends StatefulWidget {
//   final Widget child;
//   const NetworkListener({super.key, required this.child});

//   @override
//   State<NetworkListener> createState() => _NetworkListenerState();
// }

// class _NetworkListenerState extends State<NetworkListener> {
//   bool _wasOffline = false;

//   void _reloadCurrentScreen() {
//     print("[NetworkListener] Reloading current screen after reconnect...");
//     Navigator.of(context).pushReplacement(
//       PageRouteBuilder(
//         pageBuilder: (_, __, ___) => widget.child,
//         transitionDuration: const Duration(milliseconds: 300),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<bool>(
//       stream: NetworkManager.networkStatusStream,
//       builder: (context, snapshot) {
//         final isConnected = snapshot.data ?? true;

//         if (!isConnected) {
//           // When internet goes OFF
//           if (!_wasOffline) {
//             _wasOffline = true;
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               final messenger = ScaffoldMessenger.of(context);
//               messenger.clearSnackBars();
//               messenger.showSnackBar(
//                 const SnackBar(
//                   content: Text("⚠️ No internet connection"),
//                   backgroundColor: Colors.red,
//                   duration: Duration(days: 1),
//                 ),
//               );
//             });
//           }
//         } else {
//           // When internet comes back
//           if (_wasOffline) {
//             _wasOffline = false;
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               final messenger = ScaffoldMessenger.of(context);
//               messenger.clearSnackBars();
//               messenger.showSnackBar(
//                 const SnackBar(
//                   content: Text("✅ Internet reconnected"),
//                   backgroundColor: Colors.green,
//                   duration: Duration(seconds: 2),
//                 ),
//               );
//             });

//             // 🔄 Auto refresh screen after reconnect
//             Future.delayed(const Duration(seconds: 2), () {
//               _reloadCurrentScreen();
//             });
//           }
//         }

//         return widget.child;
//       },
//     );
//   }
// }
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Handles internet connectivity monitoring.
class NetworkManager {
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static Stream<bool> get networkStatusStream => _controller.stream;

  static void initialize() {
    final connectivity = Connectivity();

    // Initial connectivity check
    connectivity.checkConnectivity().then((result) {
      final isConnected = result != ConnectivityResult.none;
      print("[NetworkManager] Initial: $result (connected: $isConnected)");
      _controller.add(isConnected);
    });

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      print("[NetworkManager] Changed: $result (connected: $isConnected)");
      _controller.add(isConnected);
    });
  }

  static void dispose() {
    _controller.close();
  }
}

/// Wraps the app and displays overlay when there’s no internet.
class NetworkListener extends StatefulWidget {
  final Widget child;
  const NetworkListener({super.key, required this.child});

  @override
  State<NetworkListener> createState() => _NetworkListenerState();
}

class _NetworkListenerState extends State<NetworkListener> {
  bool _isConnected = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkManager.networkStatusStream,
      builder: (context, snapshot) {
        _isConnected = snapshot.data ?? true;

        return Stack(
          children: [
            widget.child, // 👈 your actual screen

            // 🔴 Overlay when no internet
            if (!_isConnected)
              Container(
                color: Colors.black.withOpacity(0.6),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🌐 Network-off icon
                    const Icon(
                      Icons.wifi_off,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // 🧠 Message
                    const Text(
                      "No Internet Connection",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ⏳ Loader
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "Please check your network settings.",
                      style: TextStyle(color: Colors.white70, fontSize: 14,decoration: TextDecoration.none,),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
