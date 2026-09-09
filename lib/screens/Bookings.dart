import 'package:flutter/material.dart';

import 'stylist_bookings_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => BookingsScreenState();
}

class BookingsScreenState extends State<BookingsScreen> {
  late final StylistBookingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StylistBookingsController();
  }

  Future<void> refreshFromCurrentSelection({
    bool resetDateToToday = false,
  }) {
    return _controller.refreshFromCurrentSelection(
      resetDateToToday: resetDateToToday,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StylistBookingsScreen(
      controller: _controller,
      isOwnerMode: true,
    );
  }
}
