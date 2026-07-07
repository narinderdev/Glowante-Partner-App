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
      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorNameRequired = translateText('Vendor name is required');
    final phoneRequired = translateText('Phone is required');
    final emailRequired = translateText('Email is required');
    final emailInvalid = translateText('Enter a valid email');

    return _FormCard(
      title: widget.isEdit ? context.t('Edit Vendor') : context.t('Add Vendor'),
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VendorFormIntro(isEdit: widget.isEdit),
            const SizedBox(height: 18),
            _VendorRequiredLabel(context.t('Vendor Name')),
            const SizedBox(height: 8),
            _VendorTextField(
              controller: _nameController,
              hint: context.t('Enter vendor name'),
              maxLength: 120,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  _stringValue(value).isEmpty ? vendorNameRequired : null,
            ),
            const SizedBox(height: 14),
            _VendorRequiredLabel(context.t('Phone')),
            const SizedBox(height: 8),
            _VendorTextField(
              controller: _phoneController,
              hint: context.t('Enter phone number'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              maxLength: 10,
              validator: (value) {
                final phone = _stringValue(value);
                if (phone.isEmpty) return phoneRequired;
                if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                  return translateText(
                    'Enter a valid 10-digit phone number starting with 6, 7, 8, or 9',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _VendorRequiredLabel(context.t('Email')),
            const SizedBox(height: 8),
            _VendorTextField(
              controller: _emailController,
              hint: context.t('Enter email address'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              maxLength: 120,
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
            const SizedBox(height: 16),
            _VendorStatusSwitch(
              active: _active,
              enabled: !_isSaving,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSaving
                      ? (widget.isEdit
                          ? context.t('Updating...')
                          : context.t('Saving...'))
                      : (widget.isEdit
                          ? context.t('Update Vendor')
                          : context.t('Save Vendor')),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.starColor.withValues(alpha: 0.55),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0x338B6500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorFormIntro extends StatelessWidget {
  const _VendorFormIntro({required this.isEdit});

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8C774)),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.starColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit
                      ? context.t('Update vendor details')
                      : context.t('Create a vendor profile'),
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context
                      .t('Keep supplier contact and status details current.'),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorRequiredLabel extends StatelessWidget {
  const _VendorRequiredLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF4B4038),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.redAccent,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorTextField extends StatelessWidget {
  const _VendorTextField({
    required this.controller,
    required this.hint,
    required this.validator,
    required this.maxLength,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.inputFormatters,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.words,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;
  final int maxLength;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autocorrect;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      validator: validator,
       autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: Color(0xFF1C1917),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 11,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F4F3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintStyle: const TextStyle(
          color: Color(0xFFAAA19A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8DED6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8DED6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFFD0A244),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }
}

class _VendorStatusSwitch extends StatelessWidget {
  const _VendorStatusSwitch({
    required this.active,
    required this.enabled,
    required this.onChanged,
  });

  final bool active;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE9F8EF) : const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              active ? Icons.verified_rounded : Icons.block_rounded,
              color: active ? const Color(0xFF168546) : Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Vendor Status'),
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? context.t('Active') : context.t('Inactive'),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: AppColors.starColor,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> vendor;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _name =>
      _firstText(vendor, const ['name', 'vendorName'], fallback: 'N/A');

  String get _phone => _firstText(
        vendor,
        const ['phoneNumber', 'phone', 'mobileNumber', 'contactNumber'],
        fallback: 'N/A',
      );

  String get _email => _firstText(vendor, const ['email'], fallback: 'N/A');

  bool get _active => _boolValue(vendor['active'], fallback: true);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8DED6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VendorAvatar(name: _name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1C1917),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('Vendor profile'),
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _VendorStatusPill(active: _active),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _VendorFact(
                  icon: Icons.phone_outlined,
                  label: context.t('Phone'),
                  value: _phone,
                ),
                _VendorFact(
                  icon: Icons.mail_outline_rounded,
                  label: context.t('Email'),
                  value: _email,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: Text(context.t('View')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _VendorActionButton(
                  icon: Icons.edit_outlined,
                  color: AppColors.starColor,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                _VendorActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorAvatar extends StatelessWidget {
  const _VendorAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'V' : name.characters.first;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: AppColors.starColor,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VendorStatusPill extends StatelessWidget {
  const _VendorStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF168546) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.t(active ? 'Active' : 'Inactive').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _VendorFact extends StatelessWidget {
  const _VendorFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.starColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorActionButton extends StatelessWidget {
  const _VendorActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: EdgeInsets.zero,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: Icon(icon, size: 19),
      ),
    );
  }
}
