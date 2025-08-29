import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddDealsScreen extends StatefulWidget {
  @override
  _AddDealsScreenState createState() => _AddDealsScreenState();
}

class _AddDealsScreenState extends State<AddDealsScreen> {
  // Controller for text fields
  final TextEditingController salonNameController = TextEditingController();
  final TextEditingController dealTitleController = TextEditingController();
  final TextEditingController validFromController = TextEditingController();
  final TextEditingController validTillController = TextEditingController();
  final TextEditingController actualPriceController = TextEditingController();
  final TextEditingController discountedPriceController = TextEditingController();
  final TextEditingController minOrderValueController = TextEditingController();
  final TextEditingController maxDiscountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // For handling checkbox selection
  List<String> selectedServices = [];

  // Function to format date to DD:MM:YYYY
  String _formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Deals"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Salon Name
            TextField(
              controller: salonNameController,
              decoration: InputDecoration(
                labelText: 'Salon Name *',
                hintText: 'Enter your salon name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Deal Title
            TextField(
              controller: dealTitleController,
              decoration: InputDecoration(
                labelText: 'Deal Title *',
                hintText: "e.g. Men’s Grooming Package",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Valid From and Valid Till in a single row
            Row(
              children: [
                // Valid From (Date Picker)
                Expanded(
                  child: TextField(
                    controller: validFromController,
                    decoration: InputDecoration(
                      labelText: 'Valid From *',
                      hintText: 'e.g. 15:01:2025',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        validFromController.text = _formatDate(pickedDate);
                      }
                    },
                  ),
                ),
                SizedBox(width: 16), // Space between the two fields
                // Valid Till (Date Picker)
                Expanded(
                  child: TextField(
                    controller: validTillController,
                    decoration: InputDecoration(
                      labelText: 'Valid Till *',
                      hintText: 'e.g. 19:01:2025',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        validTillController.text = _formatDate(pickedDate);
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Actual Price
            TextField(
              controller: actualPriceController,
              decoration: InputDecoration(
                labelText: 'Actual Price *',
                hintText: 'e.g. 1200',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),

            // Discounted Price
            TextField(
              controller: discountedPriceController,
              decoration: InputDecoration(
                labelText: 'Discounted Price',
                hintText: 'e.g. 1000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),

            // Minimum Order Value
            TextField(
              controller: minOrderValueController,
              decoration: InputDecoration(
                labelText: 'Minimum Order Value *',
                hintText: 'Min. booking value',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Maximum Discount
            TextField(
              controller: maxDiscountController,
              decoration: InputDecoration(
                labelText: 'Maximum Discount',
                hintText: 'Percentage-based',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Service List (Checkbox)
            Text('Service List'),
            CheckboxListTile(
              title: Text("Papaya Facial"),
              value: selectedServices.contains("Papaya Facial"),
              onChanged: (bool? value) {
                setState(() {
                  if (value!) {
                    selectedServices.add("Papaya Facial");
                  } else {
                    selectedServices.remove("Papaya Facial");
                  }
                });
              },
            ),
            CheckboxListTile(
              title: Text("Hair Styling"),
              value: selectedServices.contains("Hair Styling"),
              onChanged: (bool? value) {
                setState(() {
                  if (value!) {
                    selectedServices.add("Hair Styling");
                  } else {
                    selectedServices.remove("Hair Styling");
                  }
                });
              },
            ),
            SizedBox(height: 16),

            // Description
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g. Free Cancellation, How to use...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Submit Button
            ElevatedButton(
              onPressed: () {
                // Handle submission logic here (e.g., saving data)
                print("Salon Name: ${salonNameController.text}");
                print("Deal Title: ${dealTitleController.text}");
                print("Valid From: ${validFromController.text}");
                print("Valid Till: ${validTillController.text}");
                print("Actual Price: ${actualPriceController.text}");
                print("Discounted Price: ${discountedPriceController.text}");
                print("Min Order Value: ${minOrderValueController.text}");
                print("Max Discount: ${maxDiscountController.text}");
                print("Selected Services: $selectedServices");
                print("Description: ${descriptionController.text}");
              },
              child: Text('Add Deal'),
            ),
          ],
        ),
      ),
    );
  }
}
