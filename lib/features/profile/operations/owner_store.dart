part of 'owner_profile_operations_screen.dart';

final RegExp _storeAllowedTextPattern = RegExp(r'^[A-Za-z0-9 ]*$');
final RegExp _storeAllowedTextInputPattern = RegExp(r'[A-Za-z0-9 ]');

List<TextInputFormatter> _storeTextInputFormatters({required int maxLength}) {
  return <TextInputFormatter>[
    FilteringTextInputFormatter.allow(_storeAllowedTextInputPattern),
    LengthLimitingTextInputFormatter(maxLength),
  ];
}

String? _storeTextValidator(
  BuildContext context,
  String? value, {
  required String requiredMessage,
  bool required = false,
}) {
  final text = _stringValue(value);
  if (required && text.isEmpty) return context.t(requiredMessage);
  if (text.isNotEmpty && !_storeAllowedTextPattern.hasMatch(text)) {
    return context.t('Only letters, numbers, and spaces are allowed');
  }
  return null;
}

class _StoreFormView extends StatefulWidget {
  const _StoreFormView({
    required this.isEdit,
    required this.onBack,
    required this.onSubmit,
    this.initialStore,
  });

  final bool isEdit;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;
  final Map<String, dynamic>? initialStore;

  @override
  State<_StoreFormView> createState() => _StoreFormViewState();
}

// class _StoreFormViewState extends State<_StoreFormView> {
//   final _formKey = GlobalKey<FormState>();
//   late final TextEditingController _nameController;
//   late final TextEditingController _addressController;
//   late final TextEditingController _binController;
//   bool _active = true;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     final initial = widget.initialStore ?? const <String, dynamic>{};
//     _nameController = TextEditingController(
//       text: _firstText(initial, const ['name', 'storeName']),
//     );
//     _addressController = TextEditingController(
//       text: _firstText(initial, const ['address']),
//     );
//     _binController = TextEditingController(
//       text: _firstText(initial, const ['binDescription', 'bin']),
//     );
//     _active = _boolValue(initial['active'], fallback: true);
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _addressController.dispose();
//     _binController.dispose();
//     super.dispose();
//   }

//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() => _isSaving = true);
//     try {
//       await widget.onSubmit(<String, dynamic>{
//         'name': _nameController.text.trim(),
//         'address': _addressController.text.trim(),
//         'binDescription': _binController.text.trim(),
//         'active': _active,
//       });
//     } catch (error) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text(error.toString())));
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _FormCard(
//       title: widget.isEdit ? context.t('Edit Store') : context.t('Add Store'),
//       onBack: widget.onBack,
//       child: Form(
//         key: _formKey,
//         child: Column(
//           children: [
//             TextFormField(
//               maxLength: 120,
//               controller: _nameController,
//               decoration: InputDecoration(labelText: context.t('Store Name')),
//               validator: (value) => _stringValue(value).isEmpty
//                   ? context.t('Store name is required')
//                   : null,
//             ),
//             const SizedBox(height: 14),
//             TextFormField(
//               maxLength: 120,
//               controller: _addressController,
//               maxLines: 1,
//               decoration: InputDecoration(labelText: context.t('Address')),
//               validator: (value) => _stringValue(value).isEmpty
//                   ? context.t('Address is required')
//                   : null,
//             ),
//             const SizedBox(height: 14),
//             TextFormField(
//               maxLength: 120,
//               controller: _binController,
//               decoration:
//                   InputDecoration(labelText: context.t('Bin Description')),
//             ),
//             const SizedBox(height: 10),
//             SwitchListTile(
//               contentPadding: EdgeInsets.zero,
//               title: Text(context.t('Active')),
//               value: _active,
//               onChanged:
//                   _isSaving ? null : (value) => setState(() => _active = value),
//             ),
//             const SizedBox(height: 14),
//             Align(
//               alignment: Alignment.centerRight,
//               child: ElevatedButton(
//                 onPressed: _isSaving ? null : _submit,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.starColor,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: Text(_isSaving
//                     ? (widget.isEdit
//                         ? context.t('Updating...')
//                         : context.t('Saving...'))
//                     : (widget.isEdit
//                         ? context.t('Update Store')
//                         : context.t('Save Store'))),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
class _StoreFormViewState extends State<_StoreFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _binController;

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  bool _active = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialStore ?? const <String, dynamic>{};

    _nameController = TextEditingController(
      text: _firstText(initial, const ['name', 'storeName']),
    );

    _addressController = TextEditingController(
      text: _firstText(initial, const ['address']),
    );

    _binController = TextEditingController(
      text: _firstText(initial, const ['binDescription', 'bin']),
    );

    _active = _boolValue(initial['active'], fallback: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _binController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSubmit(<String, dynamic>{
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'binDescription': _binController.text.trim(),
        'active': _active,
      });
    } catch (error) {
      if (!mounted) return;

      Fluttertoast.showToast(msg: error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitLabel = _isSaving
        ? (widget.isEdit ? context.t('Updating...') : context.t('Saving...'))
        : (widget.isEdit ? context.t('Update Store') : context.t('Save Store'));

    return _FormCard(
      title: widget.isEdit ? context.t('Edit Store') : context.t('Add Store'),
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8DED6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D5),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFE8C774)),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.starColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('Store Details'),
                          style: const TextStyle(
                            color: Color(0xFF1C1917),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StoreStatusPill(active: _active),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLength: 50,
                    controller: _nameController,
                    inputFormatters: _storeTextInputFormatters(maxLength: 50),
                    textCapitalization: TextCapitalization.words,
                    decoration: _storeInputDecoration(
                      context,
                      label: context.t('Store Name'),
                      icon: Icons.store_mall_directory_outlined,
                    ),
                    validator: (value) => _storeTextValidator(
                      context,
                      value,
                      requiredMessage: 'Store name is required',
                      required: true,
                    ),
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 50,
                    controller: _addressController,
                    inputFormatters: _storeTextInputFormatters(maxLength: 50),
                    maxLines: 1,
                    textCapitalization: TextCapitalization.words,
                    decoration: _storeInputDecoration(
                      context,
                      label: context.t('Address'),
                      icon: Icons.location_on_outlined,
                    ),
                    validator: (value) => _storeTextValidator(
                      context,
                      value,
                      requiredMessage: 'Address is required',
                    ),
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 100,
                    controller: _binController,
                    inputFormatters: _storeTextInputFormatters(maxLength: 100),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _storeInputDecoration(
                      context,
                      label: context.t('Bin Description'),
                      icon: Icons.inventory_2_outlined,
                    ),
                    validator: (value) => _storeTextValidator(
                      context,
                      value,
                      requiredMessage: 'Bin Description is required',
                    ),
                    onChanged: (_) {
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        context.t('Active'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      subtitle: Text(
                        _active
                            ? context.t('Store is visible for operations')
                            : context.t('Store is inactive'),
                        style: const TextStyle(
                          color: Color(0xFF78716C),
                          fontSize: 12,
                        ),
                      ),
                      activeColor: AppColors.starColor,
                      value: _active,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _active = value);
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : widget.onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.starColor,
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Color(0xFFE3D6C8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(context.t('Cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      elevation: 4,
                      shadowColor: AppColors.starColor.withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(submitLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _storeInputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.starColor),
      filled: true,
      fillColor: Colors.white,
      counterStyle: const TextStyle(
        color: Color(0xFF8A8178),
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE3D6C8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.starColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.4),
      ),
    );
  }
}

class _StoreStatusPill extends StatelessWidget {
  const _StoreStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF059669) : const Color(0xFFE11D48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        context.t(active ? 'Active' : 'Inactive'),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StoreDetailsView extends StatelessWidget {
  const _StoreDetailsView({
    required this.detail,
    required this.onEdit,
  });

  final Map<String, dynamic> detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = _firstText(
      detail,
      const <String>['name', 'storeName'],
      fallback: context.t('Store'),
    );
    final address = _firstText(detail, const <String>['address']);
    final binDescription = _firstText(
      detail,
      const <String>['binDescription', 'bin'],
    );
    final active = _statusLabel(detail) == 'ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8DED6)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.starColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1C1917),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('Inventory store'),
                      style: const TextStyle(
                        color: Color(0xFF78716C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StoreStatusPill(active: active),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8DED6)),
          ),
          child: Column(
            children: [
              _StoreDetailsTile(
                icon: Icons.badge_outlined,
                label: context.t('Name'),
                value: name,
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StoreDetailsTile(
                  icon: Icons.location_on_outlined,
                  label: context.t('Address'),
                  value: address,
                ),
              ],
              if (binDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StoreDetailsTile(
                  icon: Icons.inventory_2_outlined,
                  label: context.t('Bin Description'),
                  value: binDescription,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.t('Edit Store')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            elevation: 5,
            shadowColor: AppColors.starColor.withValues(alpha: 0.22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreDetailsTile extends StatelessWidget {
  const _StoreDetailsTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.starColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF8A8178),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1C1917),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
