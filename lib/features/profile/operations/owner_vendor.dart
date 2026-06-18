part of 'owner_profile_operations_screen.dart';

class _VendorFormView extends StatefulWidget {
  const _VendorFormView({
    required this.isEdit,
    required this.onBack,
    required this.onSubmit,
    this.initialVendor,
  });

  final bool isEdit;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;
  final Map<String, dynamic>? initialVendor;

  @override
  State<_VendorFormView> createState() => _VendorFormViewState();
}

class _VendorFormViewState extends State<_VendorFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _active = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialVendor ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: _firstText(initial, const ['name', 'vendorName']),
    );
    _phoneController = TextEditingController(
      text: _firstText(
        initial,
        const ['phoneNumber', 'phone', 'mobileNumber', 'contactNumber'],
      ),
    );
    _emailController = TextEditingController(
      text: _firstText(initial, const ['email']),
    );
    _active = _boolValue(initial['active'], fallback: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final vendorName = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      await widget.onSubmit(<String, dynamic>{
        'name': vendorName,
        'vendorName': vendorName,
        'phone': phone,
        'phoneNumber': phone,
        'email': _emailController.text.trim(),
        'active': _active,
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorNameRequired = translateText('Vendor name is required');
    final phoneRequired = translateText('Phone is required');
    final phoneDigits = translateText('Phone must be exactly 10 digits');
    final emailRequired = translateText('Email is required');
    final emailInvalid = translateText('Enter a valid email');

    return _FormCard(
      title: widget.isEdit ? context.t('Edit Vendor') : context.t('Add Vendor'),
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              maxLength: 120,
              controller: _nameController,
              decoration: InputDecoration(labelText: context.t('Vendor Name')),
              validator: (value) =>
                  _stringValue(value).isEmpty ? vendorNameRequired : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              maxLength: 10,
              decoration: InputDecoration(labelText: context.t('Phone')),
              validator: (value) {
                final digits = _stringValue(value);
                if (digits.isEmpty) return phoneRequired;
                if (digits.length != 10) {
                  return phoneDigits;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              maxLength: 120,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(labelText: context.t('Email')),
              validator: (value) {
                final email = _stringValue(value);
                if (email.isEmpty) return emailRequired;
                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!regex.hasMatch(email)) {
                  return emailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Active')),
              value: _active,
              onChanged:
                  _isSaving ? null : (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 14),
            // Align(
            //   alignment: Alignment.centerRight,
            //   child: ElevatedButton(
            //     onPressed: _isSaving ? null : _submit,
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: AppColors.starColor,
            //       foregroundColor: Colors.white,
            //     ),
            //     child: Text(_isSaving
            //         ? (widget.isEdit
            //             ? context.t('Updating...')
            //             : context.t('Saving...'))
            //         : (widget.isEdit
            //             ? context.t('Update Vendor')
            //             : context.t('Save Vendor'))),
            //   ),
            // ),
      Align(
  alignment: Alignment.centerRight,
  child: SizedBox(
    width: widget.isEdit ? 160 : 140,
    height: 44,
    child: ElevatedButton(
      onPressed: _isSaving ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.starColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        _isSaving
            ? (widget.isEdit
                ? context.t('Updating...')
                : context.t('Saving...'))
            : (widget.isEdit
                ? context.t('Update Vendor')
                : context.t('Save Vendor')),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
),
          ],
        ),
      ),
    );
  }
}
