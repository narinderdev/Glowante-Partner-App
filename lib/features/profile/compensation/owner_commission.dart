part of 'profile_compensation_screen.dart';

extension _OwnerCommissionUi on _ProfileCompensationScreenState {
  Widget _buildCommissionScreen() {
    if (_services.isEmpty) {
      return _EmptyStateCard(
        title: context.t('No services found for this branch'),
        subtitle: context.t(
          'Commission setup needs active branch services and staff members.',
        ),
      );
    }

    final selectedService = _selectedService;
    final selectedRule = _selectedServiceRule;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F4F1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8DED6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CommissionTabButton(
                  label: context.t('Services'),
                  icon: Icons.content_cut_rounded,
                  isSelected: _commissionTab == _CommissionTab.services,
                  onTap: () {
                    _setCommissionTabValue(_CommissionTab.services);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _CommissionTabButton(
                  label: context.t('Staff Overrides'),
                  icon: Icons.groups_2_rounded,
                  isSelected: _commissionTab == _CommissionTab.overrides,
                  onTap: () {
                    _setCommissionTabValue(_CommissionTab.overrides);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _serviceSearchController,
          // maxLength: 60,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: context.t('Search services'),
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8A8178)),
            prefixIcon: const Icon(Icons.search, size: 17),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE8DED6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE8DED6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide:
                  const BorderSide(color: AppColors.starColor, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _filteredServices.isEmpty ? 86 : 114,
          child: _filteredServices.isEmpty
              ? Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFE8DED6)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.t('No matching services'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t(
                            'Try a different service name or clear the search.'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredServices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final service = _filteredServices[index];
                    final isSelected = selectedService?.id == service.id;
                    final rule = _repository.ruleForService(
                      service: service,
                      storedRules: _serviceRules,
                    );

                    return _ServiceSelectorCard(
                      service: service,
                      rule: rule,
                      isSelected: isSelected,
                      onTap: () {
                        _selectCommissionService(service.id);
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 18),
        if (selectedService == null || selectedRule == null)
          _EmptyStateCard(
            title: context.t('Select a service'),
            subtitle: context.t(
              'Choose a service to edit its default commission rule and staff overrides.',
            ),
          )
        else if (_commissionTab == _CommissionTab.services)
          _ServiceRuleEditorCard(
            service: selectedService,
            initialRule: selectedRule,
            isSaving: _isActionInProgress,
            onSave: (rule) => _saveCommissionRule(
              service: selectedService,
              rule: rule,
            ),
          )
        else
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedService.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1917),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedService.categoryName.isEmpty
                                    ? context.t('Staff override rules')
                                    : selectedService.categoryName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ActionChipButton(
                          label: _isActionInProgress
                              ? 'Saving...'
                              : context.t('Add Override'),
                          onTap: _isActionInProgress
                              ? null
                              : () {
                                  _openAddOverrideDialog();
                                },
                          filled: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_selectedServiceOverrides.isEmpty)
                      _EmptyStateCard(
                        title: context.t('No staff overrides found'),
                        subtitle: context.t(
                          'Add override rules for one or more staff members on this service.',
                        ),
                      )
                    else
                      ..._selectedServiceOverrides.map(
                        (override) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5F2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        override.staffName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C1917),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        override.ruleType ==
                                                CommissionRuleTypes.percentage
                                            ? '${_formatOverrideNumber(override.value)}%'
                                            : _formatCurrency(
                                                override.value.round()),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${context.t('Effective from')} ${_formatDate(override.effectiveFrom)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () {
                                          _openEditOverrideDialog(override);
                                        },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.starColor,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () {
                                          _deleteOverride(override.id);
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CommissionTabButton extends StatelessWidget {
  const _CommissionTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF2A2622) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF4B4038),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF4B4038),
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

class _ServiceSelectorCard extends StatelessWidget {
  const _ServiceSelectorCard({
    required this.service,
    required this.rule,
    required this.isSelected,
    required this.onTap,
  });

  final BranchServiceSummary service;
  final CommissionServiceRule rule;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final valueLabel = rule.ruleType == CommissionRuleTypes.percentage
        ? '${_formatOverrideNumber(rule.value)}%'
        : _formatCurrency(rule.value.round());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          width: 126,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2A2622) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2A2622)
                  : const Color(0xFFE8DED6),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  service.categoryName.isEmpty
                      ? context.t('Service commission')
                      : service.categoryName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.15,
                    color: isSelected
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF5F574F),
                  ),
                ),
              ),
              Text(
                rule.active ? valueLabel : context.t('Inactive'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? const Color(0xFFF2BE3F)
                      : AppColors.starColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRuleEditorCard extends StatefulWidget {
  const _ServiceRuleEditorCard({
    required this.service,
    required this.initialRule,
    required this.isSaving,
    required this.onSave,
  });

  final BranchServiceSummary service;
  final CommissionServiceRule initialRule;
  final bool isSaving;
  final Future<void> Function(CommissionServiceRule rule) onSave;

  @override
  State<_ServiceRuleEditorCard> createState() => _ServiceRuleEditorCardState();
}

class _ServiceRuleEditorCardState extends State<_ServiceRuleEditorCard> {
  late String _ruleType;
  late TextEditingController _valueController;
  late TextEditingController _notesController;
  late DateTime _effectiveFrom;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _applyRule(widget.initialRule);
  }

  @override
  void didUpdateWidget(covariant _ServiceRuleEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.id != widget.service.id ||
        oldWidget.initialRule != widget.initialRule) {
      _applyRule(widget.initialRule);
    }
  }

  void _applyRule(CommissionServiceRule rule) {
    if (_isControllerReady) {
      _valueController.dispose();
      _notesController.dispose();
    }
    _ruleType = rule.ruleType;
    _valueController = TextEditingController(
      text: rule.value == 0
          ? ''
          : rule.ruleType == CommissionRuleTypes.fixed
              ? (minorAmountToRupees(rule.value) ?? 0).toStringAsFixed(0)
              : _formatOverrideNumber(rule.value),
    );
    _notesController = TextEditingController(text: rule.notes);
    _effectiveFrom = rule.effectiveFrom;
    _active = rule.active;
  }

  bool get _isControllerReady {
    try {
      _valueController;
      _notesController;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _valueController.text = widget.initialRule.value == 0
          ? ''
          : widget.initialRule.ruleType == CommissionRuleTypes.fixed
              ? (minorAmountToRupees(widget.initialRule.value) ?? 0)
                  .toStringAsFixed(0)
              : _formatOverrideNumber(widget.initialRule.value);
      _notesController.text = widget.initialRule.notes;
      _ruleType = widget.initialRule.ruleType;
      _effectiveFrom = widget.initialRule.effectiveFrom;
      _active = widget.initialRule.active;
    });
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_valueController.text.trim());
    final invalidValue = translateText('Enter a valid commission value');
    final commissionRange =
        translateText('Commission must be between 0 and 100');
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invalidValue)),
      );
      return;
    }
    if (_ruleType == CommissionRuleTypes.percentage && parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(commissionRange)),
      );
      return;
    }

    await widget.onSave(
      CommissionServiceRule(
        serviceId: widget.service.id,
        ruleType: _ruleType,
        value: _ruleType == CommissionRuleTypes.fixed
            ? rupeesToMinorAmount(parsed).toDouble()
            : parsed,
        effectiveFrom: _effectiveFrom,
        active: _active,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DED6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.service.name,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('Default commission rule'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5F574F),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _active,
                activeThumbColor: AppColors.starColor,
                onChanged: widget.isSaving
                    ? null
                    : (value) {
                        setState(() => _active = value);
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CommissionDropdownField(
            label: context.t('Rule type'),
            value: _ruleType,
            enabled: !widget.isSaving,
            items: [
              DropdownMenuItem(
                value: CommissionRuleTypes.percentage,
                child: Text(context.t('Percentage')),
              ),
              DropdownMenuItem(
                value: CommissionRuleTypes.fixed,
                child: Text(context.t('Fixed')),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _ruleType = value);
            },
          ),
          const SizedBox(height: 12),
          _CommissionTextField(
            label: _ruleType == CommissionRuleTypes.percentage
                ? context.t('Value (%)')
                : context.t('Value (₹)'),
            controller: _valueController,
            enabled: !widget.isSaving,
            maxLength: 8,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _CommissionDateField(
            label: context.t('Effective from'),
            value: _effectiveFrom,
            onTap: widget.isSaving
                ? () {}
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _effectiveFrom,
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _effectiveFrom = picked);
                    }
                  },
          ),
          const SizedBox(height: 12),
          _CommissionTextField(
            label: context.t('Notes'),
            controller: _notesController,
            enabled: !widget.isSaving,
            maxLines: 3,
            maxLength: 120,
            hintText: context.t('Add details about this commission rule...'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          _reset();
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    foregroundColor: const Color(0xFF1C1917),
                    side: const BorderSide(color: Color(0xFFE8DED6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(context.t('Cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          _save();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(widget.isSaving
                      ? context.t('Saving...')
                      : context.t('Save Changes')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatOverrideNumber(num value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

class _CommissionFieldLabel extends StatelessWidget {
  const _CommissionFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Color(0xFF8A8178),
        ),
      ),
    );
  }
}

InputDecoration _commissionFieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9A9189)),
    filled: true,
    fillColor: const Color(0xFFF7F4F1),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE1D6CB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE1D6CB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.starColor, width: 1.2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE1D6CB)),
    ),
  );
}

class _CommissionTextField extends StatelessWidget {
  const _CommissionTextField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength = 120,
    this.keyboardType,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int maxLines;
  final int maxLength;
  final TextInputType? keyboardType;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommissionFieldLabel(label),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1917),
          ),
          decoration: _commissionFieldDecoration(hintText: hintText),
        ),
      ],
    );
  }
}

class _CommissionDropdownField extends StatelessWidget {
  const _CommissionDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommissionFieldLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: _commissionFieldDecoration(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1917),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _CommissionDateField extends StatelessWidget {
  const _CommissionDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommissionFieldLabel(label),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4F1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1D6CB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: AppColors.starColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddOverrideDialog extends StatefulWidget {
  const _AddOverrideDialog({
    required this.title,
    required this.submitLabel,
    required this.serviceId,
    required this.staff,
    required this.onSubmit,
    this.initialOverride,
  });

  final String title;
  final String submitLabel;
  final int serviceId;
  final List<ProfileTeamMember> staff;
  final Future<void> Function(List<StaffCommissionOverride> overrides) onSubmit;
  final StaffCommissionOverride? initialOverride;

  @override
  State<_AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<_AddOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedStaffIds = <int>{};
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _ruleType;
  DateTime _effectiveFrom = DateTime.now();
  bool _isSaving = false;
  bool get _isEdit => widget.initialOverride != null;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOverride;
    if (initial != null) {
      _selectedStaffIds.add(initial.staffId);
      _ruleType = initial.ruleType;
      _effectiveFrom = initial.effectiveFrom;
      _valueController.text = initial.ruleType == CommissionRuleTypes.fixed
          ? (minorAmountToRupees(initial.value) ?? 0).toStringAsFixed(0)
          : _formatOverrideNumber(initial.value);
      _notesController.text = initial.notes;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateIfNeeded() {
    if (_autoValidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final parsed = double.parse(_valueController.text.trim());
    final ruleType = _ruleType ?? CommissionRuleTypes.percentage;

    final overrides = widget.staff
        .where((member) => _selectedStaffIds.contains(member.id))
        .map(
          (member) => StaffCommissionOverride(
            id: '${widget.serviceId}_${member.id}_${DateTime.now().millisecondsSinceEpoch}',
            serviceId: widget.serviceId,
            staffId: member.id,
            staffName: member.name,
            ruleType: ruleType,
            value: ruleType == CommissionRuleTypes.fixed
                ? rupeesToMinorAmount(parsed).toDouble()
                : parsed,
            effectiveFrom: _effectiveFrom,
            notes: _notesController.text.trim(),
          ),
        )
        .toList();

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(overrides);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEdit) ...[
                  Text(
                    context.t('Editing staff'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: Text(
                      widget.initialOverride?.staffName ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else ...[
                  FormField<Set<int>>(
                    initialValue: _selectedStaffIds.toSet(),
                    validator: (_) => _selectedStaffIds.isEmpty
                        ? translateText('Select at least one staff member')
                        : null,
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Select staff'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.staff.map((member) {
                              final isSelected =
                                  _selectedStaffIds.contains(member.id);
                              return FilterChip(
                                label: Text(member.name),
                                selected: isSelected,
                                onSelected: _isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value) {
                                            _selectedStaffIds.add(member.id);
                                          } else {
                                            _selectedStaffIds.remove(member.id);
                                          }
                                        });
                                        field.didChange(_selectedStaffIds.toSet());
                                        _validateIfNeeded();
                                      },
                              );
                            }).toList(),
                          ),
                          if (field.errorText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              field.errorText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _ruleType,
                  decoration: InputDecoration(
                    labelText: context.t('Rule type'),
                  ),
                  validator: (value) => value == null
                      ? translateText('Rule type is required')
                      : null,
                  items: [
                    DropdownMenuItem(
                      value: CommissionRuleTypes.percentage,
                      child: Text(context.t('Percentage')),
                    ),
                    DropdownMenuItem(
                      value: CommissionRuleTypes.fixed,
                      child: Text(context.t('Fixed')),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _ruleType = value);
                          _validateIfNeeded();
                        },
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: context.t('Value'),
                  controller: _valueController,
                  enabled: !_isSaving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return translateText('Enter a valid override value');
                    }
                    final parsed = double.tryParse(text);
                    if (parsed == null || parsed <= 0) {
                      return translateText('Enter a valid override value');
                    }
                    if (_ruleType == CommissionRuleTypes.percentage &&
                        parsed > 100) {
                      return translateText(
                        'Commission must be between 0 and 100',
                      );
                    }
                    return null;
                  },
                  onChanged: _isSaving
                      ? null
                      : (_) {
                          _validateIfNeeded();
                        },
                ),
                const SizedBox(height: 12),
                _DateFieldButton(
                  label: context.t('Effective from'),
                  value: _effectiveFrom,
                  onTap: _isSaving
                      ? () {}
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _effectiveFrom,
                            firstDate: DateTime(2022),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _effectiveFrom = picked);
                          }
                        },
                ),
                const SizedBox(height: 12),
                _LabeledTextField(
                  label: context.t('Notes'),
                  controller: _notesController,
                  enabled: !_isSaving,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.t('Cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(context.t('Saving...')),
                  ],
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
