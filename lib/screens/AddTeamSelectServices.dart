import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'package:flutter/services.dart';

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
        SnackBar(
            content: Text(translateText("Please select at least one service"))),
      );
      return;
    }

    // Prepare the final payload with the selected services
    final finalPayload = {
      ...widget.teamPayload,
      //  "salonId": widget.salonId,
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
      SnackBar(content: Text(translateText("Team member added successfully"))),
    );
  }

  int? _parseServiceId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) return int.tryParse(rawId);
    return null;
  }

  List<int> _collectServiceIds(List<dynamic> services) {
    final result = <int>[];
    for (final service in services) {
      if (service is Map) {
        final int? id = _parseServiceId(service['id']);
        if (id != null) result.add(id);
      }
    }
    return result;
  }

  void _toggleSelectAll(List<int> ids, bool select) {
    if (ids.isEmpty) return;
    setState(() {
      if (select) {
        _selectedServiceIds.addAll(ids);
      } else {
        _selectedServiceIds.removeAll(ids);
      }
    });
  }

  Widget _buildSelectAllButton({
    required List<int> ids,
    required bool allSelected,
    required bool partiallySelected,
  }) {
    final IconData icon;
    if (allSelected) {
      icon = Icons.check_box;
    } else if (partiallySelected) {
      icon = Icons.indeterminate_check_box;
    } else {
      icon = Icons.check_box_outline_blank;
    }

    return IconButton(
      splashRadius: 20,
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: AppColors.starColor),
      tooltip: allSelected
          ? translateText("Clear selection")
          : translateText("Select all"),
      onPressed: ids.isEmpty ? null : () => _toggleSelectAll(ids, !allSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Let the gradient show through:
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Ensure status bar + icons look good on the gradient:
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: Colors.white, // back button color
        ),
        title: Text(
          translateText('Select Services'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Paint the gradient here:
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.starColor, // your start color
                AppColors.getStartedButton, // your end color
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final categoryMap =
                    Map<String, dynamic>.from(_categories[i] as Map);
                final List<dynamic> services =
                    categoryMap['services'] as List? ?? const [];
                final List<dynamic> subCats =
                    categoryMap['subCategories'] as List? ?? const [];

                final List<int> categoryServiceIds =
                    _collectServiceIds(services);
                final bool categoryAllSelected =
                    categoryServiceIds.isNotEmpty &&
                        categoryServiceIds.every(_selectedServiceIds.contains);
                final bool categoryPartialSelected = !categoryAllSelected &&
                    categoryServiceIds.any(_selectedServiceIds.contains);

                return ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryMap['displayName'] ??
                              categoryMap['name'] ??
                              'Unnamed',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      if (categoryServiceIds.isNotEmpty)
                        _buildSelectAllButton(
                          ids: categoryServiceIds,
                          allSelected: categoryAllSelected,
                          partiallySelected: categoryPartialSelected,
                        ),
                    ],
                  ),
                  children: [
                    ...services.map<Widget>((srv) {
                      final serviceMap = Map<String, dynamic>.from(srv as Map);
                      final int? id = _parseServiceId(serviceMap['id']);
                      if (id == null) return const SizedBox.shrink();
                      final name =
                          serviceMap['displayName'] ?? serviceMap['name'] ?? '';
                      final price = serviceMap['priceMinor'] ?? 0;
                      final duration = serviceMap['durationMin'] ?? 0;
                      final desc = serviceMap['description'] ?? '';
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
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          '₹$price • $duration min\n$desc',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black),
                        ),
                        checkColor: Colors.black,
                        activeColor: Colors.black,
                        selectedTileColor: Colors.black,
                      );
                    }),
                    ...subCats.map<Widget>((sub) {
                      final subMap = Map<String, dynamic>.from(sub as Map);
                      final List<dynamic> subServices =
                          subMap['services'] as List? ?? const [];
                      final List<int> subServiceIds =
                          _collectServiceIds(subServices);

                      final bool subAllSelected = subServiceIds.isNotEmpty &&
                          subServiceIds.every(_selectedServiceIds.contains);
                      final bool subPartialSelected = !subAllSelected &&
                          subServiceIds.any(_selectedServiceIds.contains);

                      return ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subMap['displayName'] ??
                                    subMap['name'] ??
                                    'Unnamed',
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                            if (subServiceIds.isNotEmpty)
                              _buildSelectAllButton(
                                ids: subServiceIds,
                                allSelected: subAllSelected,
                                partiallySelected: subPartialSelected,
                              ),
                          ],
                        ),
                        children: subServices.map<Widget>((srv) {
                          final srvMap = Map<String, dynamic>.from(srv as Map);
                          final int? id = _parseServiceId(srvMap['id']);
                          if (id == null) return const SizedBox.shrink();
                          final checked = _selectedServiceIds.contains(id);
                          final name =
                              srvMap['displayName'] ?? srvMap['name'] ?? '';
                          final price = srvMap['priceMinor'] ?? 0;
                          final duration = srvMap['durationMin'] ?? 0;
                          final desc = srvMap['description'] ?? '';

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
                              style: const TextStyle(color: Colors.black),
                            ),
                            subtitle: Text(
                              '₹$price • $duration min\n$desc',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black),
                            ),
                            checkColor: Colors.white,
                            activeColor: AppColors.starColor,
                            selectedTileColor: Colors.white,
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          child: _isSubmitting
              ? const CircularProgressIndicator(color: AppColors.starColor)
              : Text(translateText("Submit")),
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
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
