import 'package:flutter/material.dart';

class ReviewsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the app bar completely
      appBar: null,
      body: Center(
        child: Text('Reviews'),
      ),
    );
  }
}
