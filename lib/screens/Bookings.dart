import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookings"),
        backgroundColor: Colors.purple,
      ),
      body: const Center(
        child: Text(
          "Bookings Screen",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
