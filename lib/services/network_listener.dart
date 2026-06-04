import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';


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
                    Icon(
                      Icons.wifi_off,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),

                    // 🧠 Message
                    Text(translateText("No Internet Connection"),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 12),

                    // ⏳ Loader
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),

                    SizedBox(height: 20),
                    Text(translateText("Please check your network settings."),
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
