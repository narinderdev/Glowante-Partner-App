part of 'owner_profile_operations_screen.dart';

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

class _StoreFormViewState extends State<_StoreFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _binController;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: widget.isEdit ? context.t('Edit Store') : context.t('Add Store'),
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: context.t('Store Name')),
              validator: (value) => _stringValue(value).isEmpty
                  ? context.t('Store name is required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              maxLines: 1,
              decoration: InputDecoration(labelText: context.t('Address')),
              validator: (value) => _stringValue(value).isEmpty
                  ? context.t('Address is required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _binController,
              decoration:
                  InputDecoration(labelText: context.t('Bin Description')),
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
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isSaving
                    ? (widget.isEdit
                        ? context.t('Updating...')
                        : context.t('Saving...'))
                    : (widget.isEdit
                        ? context.t('Update Store')
                        : context.t('Save Store'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
