import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

/// Handles internet connectivity monitoring.
class NetworkManager {
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static final Connectivity _connectivity = Connectivity();
  static Timer? _recoveryTimer;
  static bool? _lastIsConnected;
  static String? _recoveryHost;

  static Stream<bool> get networkStatusStream => _controller.stream;

  static void initialize() {
    unawaited(_refreshConnectionStatus(validateInternet: true));

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = _hasConnection(results);
      assert(() {
        debugPrint(
            "[NetworkManager] Changed: $results (connected: $isConnected)");
        return true;
      }());

      if (isConnected) {
        unawaited(_refreshConnectionStatus(validateInternet: true));
      } else {
        _setConnectionStatus(false);
        _startRecoveryPolling();
      }
    });
  }

  static void reportNetworkIssue(Object? error, {Uri? uri}) {
    if (!_isNetworkIssue(error)) return;

    final host = uri?.host.trim();
    if (host != null && host.isNotEmpty) {
      _recoveryHost = host;
    }

    assert(() {
      debugPrint("[NetworkManager] Reported network issue: $error");
      return true;
    }());

    _setConnectionStatus(false);
    _startRecoveryPolling();
  }

  static void reportSuccessfulRequest() {
    _stopRecoveryPolling();
    _setConnectionStatus(true);
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  static Future<void> _refreshConnectionStatus({
    required bool validateInternet,
  }) async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = _hasConnection(results);
      assert(() {
        debugPrint(
            "[NetworkManager] Checked: $results (connected: $hasConnection)");
        return true;
      }());

      if (!hasConnection) {
        _setConnectionStatus(false);
        _startRecoveryPolling();
        return;
      }

      if (!validateInternet) {
        _stopRecoveryPolling();
        _setConnectionStatus(true);
        return;
      }

      final canReachInternet = await _canReachInternet();
      _setConnectionStatus(canReachInternet);
      if (canReachInternet) {
        _stopRecoveryPolling();
      } else {
        _startRecoveryPolling();
      }
    } catch (error) {
      reportNetworkIssue(error);
    }
  }

  static Future<bool> _canReachInternet() async {
    final host = _recoveryHost?.trim().isNotEmpty == true
        ? _recoveryHost!.trim()
        : 'example.com';

    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (error) {
      assert(() {
        debugPrint("[NetworkManager] Internet validation failed: $error");
        return true;
      }());
      return false;
    }
  }

  static bool _isNetworkIssue(Object? error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('connection timed out') ||
        message.contains('timed out') ||
        message.contains('clientexception with socketexception');
  }

  static void _setConnectionStatus(bool isConnected) {
    if (_lastIsConnected == isConnected) return;
    _lastIsConnected = isConnected;
    _controller.add(isConnected);
  }

  static void _startRecoveryPolling() {
    if (_recoveryTimer?.isActive == true) return;
    _recoveryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshConnectionStatus(validateInternet: true));
    });
  }

  static void _stopRecoveryPolling() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryHost = null;
  }

  static void dispose() {
    _stopRecoveryPolling();
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
  bool _hasBeenOffline = false;
  bool _showWelcomeBack = false;
  Timer? _welcomeBackTimer;

  @override
  void dispose() {
    _welcomeBackTimer?.cancel();
    super.dispose();
  }

  void _handleConnectionChanged(bool isConnected) {
    if (_isConnected == isConnected) return;

    _welcomeBackTimer?.cancel();
    setState(() {
      _isConnected = isConnected;
      if (!isConnected) {
        _hasBeenOffline = true;
        _showWelcomeBack = false;
      } else if (_hasBeenOffline) {
        _showWelcomeBack = true;
      }
    });

    if (isConnected && _hasBeenOffline) {
      _welcomeBackTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _showWelcomeBack = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkManager.networkStatusStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleConnectionChanged(isConnected);
        });

        return Stack(
          children: [
            widget.child, // 👈 your actual screen

            // 🔴 Overlay when no internet
            if (!_isConnected)
              const Positioned.fill(child: _NoInternetOverlay()),
            if (_showWelcomeBack)
              const Positioned.fill(child: _WelcomeBackOverlay()),
          ],
        );
      },
    );
  }
}

class _NoInternetOverlay extends StatelessWidget {
  const _NoInternetOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.68),
        alignment: Alignment.center,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1D6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF8B6500),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                translateText('No Internet Connection'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: Color(0xFF2F2924),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                translateText('Waiting for connection...'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7A7068),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF8B6500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBackOverlay extends StatelessWidget {
  const _WelcomeBackOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: const BoxDecoration(
                color: Color(0xFF0F9F6E),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      translateText('Welcome back! You are online.'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
