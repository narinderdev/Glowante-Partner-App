// lib/screens/web_doc_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for SystemUiOverlayStyle
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/colors.dart';

class WebDocScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebDocScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<WebDocScreen> createState() => _WebDocScreenState();
}

class _WebDocScreenState extends State<WebDocScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _errorText = null;
          }),
          onProgress: (_) {
            // you can also show incremental progress if you want
          },
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            // Show a friendly message; keeps the screen from looking "black"
            setState(() {
              _loading = false;
              _errorText = 'Failed to load page (${err.errorCode}): ${err.description}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // WebView
          if (_errorText == null)
            WebViewWidget(controller: _controller),

          // Error state (covers the WebView with a message + retry)
          if (_errorText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _errorText = null;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),

          // Loader (star color) while loading
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.starColor),
              ),
            ),
        ],
      ),
    );
  }
}
