// lib/screens/web_doc_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

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
              _errorText =
                  'Failed to load page (${err.errorCode}): ${err.description}';
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
      appBar: buildProfileSubpageAppBar(title: widget.title),
      body: Stack(
        children: [
          // WebView
          if (_errorText == null) WebViewWidget(controller: _controller),

          // Error state (covers the WebView with a message + retry)
          if (_errorText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    SizedBox(height: 16),
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
                      child: Text(translateText('Try again')),
                    ),
                  ],
                ),
              ),
            ),

          // Loader (star color) while loading
          if (_loading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.starColor),
              ),
            ),
        ],
      ),
    );
  }
}
