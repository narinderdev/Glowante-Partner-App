import 'package:flutter/material.dart';

class AddStylistScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Stylist'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stylist Name', style: TextStyle(fontSize: 18)),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text('Specialization', style: TextStyle(fontSize: 18)),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter specialization',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Handle add stylist logic
              },
              child: Text('Add Stylist'),
            ),
          ],
        ),
      ),
    );
  }
}
