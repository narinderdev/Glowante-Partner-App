import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

class StylistWebDocScreen extends StatefulWidget {
  final String title;
  final String url;

  const StylistWebDocScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<StylistWebDocScreen> createState() => _StylistWebDocScreenState();
}

class _StylistWebDocScreenState extends State<StylistWebDocScreen> {
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
          onProgress: (_) {},
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
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
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
          if (_errorText == null) WebViewWidget(controller: _controller),
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
