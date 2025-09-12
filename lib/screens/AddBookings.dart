import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SelectServices.dart';

class AddBookingScreen extends StatefulWidget {
  final int? salonId; // needed for SelectServicesModal
  final int? branchId; // future use when posting appointment

  const AddBookingScreen({Key? key, this.salonId, this.branchId})
      : super(key: key);

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final TextEditingController _clientNameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();

  String? _staffRole; // Salon Owner | Manager
  String? _professional; // Hair | Hair Stylist

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Selected services from modal: each {id, name, price, qty}
  List<Map<String, dynamic>> _selectedServices = [];

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Map<int, int> _selectedQtyMap() {
    final map = <int, int>{};
    for (final s in _selectedServices) {
      final id = s['id'] as int;
      final int qty = (s['qty'] ?? 0) as int;
      if (qty > 0) map[id] = qty;
    }
    return map;
  }

  double get _servicesTotal {
    double sum = 0;
    for (final s in _selectedServices) {
      final num price = (s['price'] ?? 0) as num; // in rupees already
      final int qty = (s['qty'] ?? 0) as int;
      sum += (price * qty).toDouble();
    }
    return sum;
  }

  String _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
    }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = (isStart ? _startTime : _endTime) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Ensure end >= start
          if (_endTime != null) {
            final s = _toMinutes(_startTime!);
            final e = _toMinutes(_endTime!);
            if (e <= s) {
              _endTime = TimeOfDay(hour: picked.hour, minute: picked.minute + 30);
            }
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _openSelectServices() async {
    if (widget.salonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a salon first')),
      );
      return;
    }
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: SelectServicesModal(
          salonId: widget.salonId!,
          initialSelectedQty: _selectedQtyMap(),
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedServices = result);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_staffRole == null) {
      _showError('Please select Staff Member');
      return;
    }
    if (_professional == null) {
      _showError('Please select Professional');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showError('Please select start and end time');
      return;
    }

    // Package the payload (no API call here per request)
    final payload = {
      'clientName': _clientNameCtrl.text.trim(),
      'phone': _mobileCtrl.text.trim(),
      'staffRole': _staffRole,
      'professional': _professional,
      'startTime': _formatTimeOfDay(_startTime),
      'endTime': _formatTimeOfDay(_endTime),
      'services': _selectedServices,
      'salonId': widget.salonId,
      'branchId': widget.branchId,
    };

    // For now, just pop with payload so caller can handle
    Navigator.pop(context, payload);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Booking'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name
                Text('Salon & Branch Id: ${widget.salonId ?? '-'} / ${widget.branchId ?? '-'}'),
                const _FieldLabel('Client Name *'),
                TextFormField(
                  controller: _clientNameCtrl,
                  decoration: _inputDecoration('Client name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Mobile
                const _FieldLabel('Mobile Number *'),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Enter mobile number'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Staff + Professional
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Staff Member *'),
                          _Dropdown<String>(
                            value: _staffRole,
                            hint: 'Salon Owner',
                            items: const ['Salon Owner', 'Manager'],
                            onChanged: (v) => setState(() => _staffRole = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Professional *'),
                          _Dropdown<String>(
                            value: _professional,
                            hint: 'Hair',
                            items: const ['Hair', 'Hair Stylist'],
                            onChanged: (v) => setState(() => _professional = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const _FieldLabel('Services'),
                InkWell(
                  onTap: _openSelectServices,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Colors.brown),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedServices.isEmpty
                                ? 'Select Services'
                                : '${_selectedServices.length} selected  •  ₹${_servicesTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        // const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),

                if (_selectedServices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: _selectedServices
                        .map((s) => Chip(
                              label: Text('${s['name']} x${s['qty']}'),
                              onDeleted: () {
                                setState(() => _selectedServices.remove(s));
                              },
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 20),

                // Start / End time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Start Time *'),
                          InkWell(
                            onTap: () => _pickTime(isStart: true),
                            child: _TimeBox(text: _startTime == null ? 'Start Time' : _formatTimeOfDay(_startTime)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('End Time *'),
                          InkWell(
                            onTap: () => _pickTime(isStart: false),
                            child: _TimeBox(text: _endTime == null ? 'End Time' : _formatTimeOfDay(_endTime)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
    );

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const _Dropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              const Icon(Icons.sell_outlined, color: Colors.brown),
              const SizedBox(width: 6),
              Text(hint),
            ],
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String text;
  const _TimeBox({Key? key, required this.text}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? 'Select' : text)),
        ],
      ),
    );
  }
}
