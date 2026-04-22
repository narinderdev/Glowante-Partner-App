import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../stylist_item_entry_theme.dart';
import '../stylist_used_item.dart';
import '../../../utils/localization_helper.dart';

class StylistUsedItemEditorScreen extends StatefulWidget {
  const StylistUsedItemEditorScreen({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.sourceLabel,
    this.initialItem,
    this.codeReadOnly = false,
  });

  final String title;
  final String submitLabel;
  final String sourceLabel;
  final StylistUsedItem? initialItem;
  final bool codeReadOnly;

  @override
  State<StylistUsedItemEditorScreen> createState() =>
      _StylistUsedItemEditorScreenState();
}

class _StylistUsedItemEditorScreenState
    extends State<StylistUsedItemEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final item = StylistUsedItem(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _categoryController.text.trim(),
      quantity: '',
      unit: '',
      code: _codeController.text.trim(),
      notes: '',
      sourceLabel: widget.sourceLabel,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stylistItemBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 0,
        title: Text(
          context.t(widget.title),
          style: const TextStyle(
            color: stylistItemPrimaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: stylistItemPrimaryText),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _FieldCard(
                child: Column(
                  children: [
                    _ItemTextField(
                      controller: _categoryController,
                      label: context.t('Category'),
                      hint: context.t('Enter product category'),
                    ),
                    const SizedBox(height: 14),
                    _ItemTextField(
                      controller: _brandController,
                      label: context.t('Brand'),
                      hint: context.t('Enter brand name'),
                    ),
                    const SizedBox(height: 14),
                    _ItemTextField(
                      controller: _nameController,
                      label: context.t('Item name'),
                      hint: context.t('Enter product name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return translateText('Item name is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _ItemTextField(
                      controller: _codeController,
                      label: context.t('Barcode / QR code'),
                      hint: context.t('Enter or review scanned code'),
                      readOnly: widget.codeReadOnly,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: stylistItemAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.t(widget.submitLabel),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stylistItemBorder),
      ),
      child: child,
    );
  }
}

class _ItemTextField extends StatelessWidget {
  const _ItemTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.readOnly = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool readOnly;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: stylistItemPrimaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0AAA4)),
            filled: true,
            fillColor: stylistItemBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: stylistItemBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: stylistItemBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: stylistItemAccent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
