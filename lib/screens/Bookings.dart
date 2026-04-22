import 'package:flutter/material.dart';

import 'stylist_bookings_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StylistBookingsScreen(isOwnerMode: true);
  }
}
