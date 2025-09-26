import 'package:flutter/material.dart';
import '../utils/api_service.dart';

class AddTeamSelectServices extends StatefulWidget {
  final int salonId;
  final Map<String, dynamic> teamPayload;

  const AddTeamSelectServices({
    super.key,
    required this.salonId,
    required this.teamPayload,
  });

  @override
  State<AddTeamSelectServices> createState() => _AddTeamSelectServicesState();
}

class _AddTeamSelectServicesState extends State<AddTeamSelectServices> {
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _isSubmitting = false;
  final Set<int> _selectedServiceIds = {}; // store selected service IDs

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await ApiService().getService(salonId: widget.salonId);
      setState(() {
        _categories = response['data']['categories'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint("❌ Error fetching services: $e");
    }
  }

  
  Future<void> _submit() async {
    if (_selectedServiceIds.isEmpty) {
      // Show message if no service is selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service")),
      );
      return;
    }

    // Prepare the final payload with the selected services
    final finalPayload = {
      ...widget.teamPayload,
      "selectedServiceIds": _selectedServiceIds.toList(),
    };

    // Log the final payload
    debugPrint("✅ FINAL PAYLOAD: $finalPayload");

    setState(() {
      _isSubmitting = true;
    });

    // Simulating API call (replace with actual API)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Team member added successfully")),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Services"),
        backgroundColor: Colors.black, // Full black background for the app bar
        foregroundColor: Colors.white, // White text color for app bar
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final services = cat['services'] ?? [];
                final subCats = cat['subCategories'] ?? [];

                return ExpansionTile(
                  title: Text(
                    cat['displayName'] ?? cat['name'] ?? 'Unnamed',
                    style: const TextStyle(color: Colors.black), // White text
                  ),
                  children: [
                    // Services directly under category
                    ...services.map<Widget>((srv) {
                      final id = srv['id'];
                      final name = srv['displayName'] ?? srv['name'] ?? '';
                      final price = srv['priceMinor'] ?? 0;
                      final duration = srv['durationMin'] ?? 0;
                      final desc = srv['description'] ?? '';
                      final checked = _selectedServiceIds.contains(id);

                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedServiceIds.add(id);
                            } else {
                              _selectedServiceIds.remove(id);
                            }
                          });
                        },
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.black), // White text for name
                        ),
                        subtitle: Text(
                          "₹$price • $duration min\n$desc",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black), // Light grey subtitle
                        ),
                        checkColor: Colors.black,
                        activeColor: Colors.black,
                        selectedTileColor: Colors.black,
                      );
                    }),

                    // Subcategories
                    ...subCats.map<Widget>((sub) {
                      final subName =
                          sub['displayName'] ?? sub['name'] ?? 'Unnamed';
                      final subServices = sub['services'] ?? [];

                      return ExpansionTile(
                        title: Text(
                          subName,
                          style: const TextStyle(color: Colors.black), // White text for subcategory
                        ),
                        children: subServices.map<Widget>((srv) {
                          final id = srv['id'];
                          final name =
                              srv['displayName'] ?? srv['name'] ?? '';
                          final price = srv['priceMinor'] ?? 0;
                          final duration = srv['durationMin'] ?? 0;
                          final desc = srv['description'] ?? '';
                          final checked = _selectedServiceIds.contains(id);

                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedServiceIds.add(id);
                                } else {
                                  _selectedServiceIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.black), // White text for name
                            ),
                            subtitle: Text(
                              "₹$price • $duration min\n$desc",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black), // Light grey subtitle
                            ),
                            checkColor: Colors.white,
                            activeColor: Colors.black,
                            selectedTileColor: Colors.white,
                          );
                        }).toList(),
                      );
                    }),
                  ],
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.black)
              : const Text("Submit"),
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
