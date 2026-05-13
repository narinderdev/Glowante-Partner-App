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
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _ModuleButton(
                label: context.t('Services'),
                icon: Icons.design_services_outlined,
                isSelected: _commissionTab == _CommissionTab.services,
                onTap: () {
                  _setCommissionTabValue(_CommissionTab.services);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleButton(
                label: context.t('Staff Overrides'),
                icon: Icons.groups_2_outlined,
                isSelected: _commissionTab == _CommissionTab.overrides,
                onTap: () {
                  _setCommissionTabValue(_CommissionTab.overrides);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _serviceSearchController,
          decoration: InputDecoration(
            hintText: context.t('Search services'),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 136,
          child: _filteredServices.isEmpty
              ? _EmptyStateCard(
                  title: context.t('No matching services'),
                  subtitle: context.t(
                    'Try a different service name or clear the search.',
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
                                            ? '${override.value.toStringAsFixed(1)}%'
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
        ? '${rule.value.toStringAsFixed(1)}%'
        : '₹${rule.value.round()}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1C1917) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1C1917)
                  : const Color(0xFFE9DFD1),
            ),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  service.categoryName.isEmpty
                      ? context.t('Service commission')
                      : service.categoryName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                rule.active ? valueLabel : context.t('Inactive'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFFFCD34D)
                      : const Color(0xFFB45309),
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
      text: rule.value == 0 ? '' : rule.value.toStringAsFixed(1),
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
          : widget.initialRule.value.toStringAsFixed(1);
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
        value: parsed,
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
                      widget.service.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('Default commission rule'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
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
          DropdownButtonFormField<String>(
            initialValue: _ruleType,
            decoration: InputDecoration(
              labelText: context.t('Rule type'),
              filled: true,
              fillColor: const Color(0xFFF8F5F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
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
            onChanged: widget.isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _ruleType = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          _LabeledTextField(
            label: _ruleType == CommissionRuleTypes.percentage
                ? context.t('Value (%)')
                : context.t('Value (₹)'),
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _DateFieldButton(
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
          _LabeledTextField(
            label: context.t('Notes'),
            controller: _notesController,
            maxLines: 1,
          ),
          const SizedBox(height: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(widget.isSaving
                      ? context.t('Saving...')
                      : context.t('Save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddOverrideDialog extends StatefulWidget {
  const _AddOverrideDialog({
    required this.serviceId,
    required this.staff,
  });

  final int serviceId;
  final List<ProfileTeamMember> staff;

  @override
  State<_AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<_AddOverrideDialog> {
  final Set<int> _selectedStaffIds = <int>{};
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _ruleType = CommissionRuleTypes.percentage;
  DateTime _effectiveFrom = DateTime.now();

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_valueController.text.trim());
    final selectStaff = translateText('Select at least one staff member');
    final invalidOverride = translateText('Enter a valid override value');
    final commissionRange =
        translateText('Commission must be between 0 and 100');
    if (_selectedStaffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(selectStaff)),
      );
      return;
    }
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invalidOverride)),
      );
      return;
    }
    if (_ruleType == CommissionRuleTypes.percentage && parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(commissionRange)),
      );
      return;
    }

    final overrides = widget.staff
        .where((member) => _selectedStaffIds.contains(member.id))
        .map(
          (member) => StaffCommissionOverride(
            id: '${widget.serviceId}_${member.id}_${DateTime.now().millisecondsSinceEpoch}',
            serviceId: widget.serviceId,
            staffId: member.id,
            staffName: member.name,
            ruleType: _ruleType,
            value: parsed,
            effectiveFrom: _effectiveFrom,
            notes: _notesController.text.trim(),
          ),
        )
        .toList();

    Navigator.pop(context, overrides);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('Add Override')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('Select staff'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.staff.map((member) {
                  final isSelected = _selectedStaffIds.contains(member.id);
                  return FilterChip(
                    label: Text(member.name),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedStaffIds.add(member.id);
                        } else {
                          _selectedStaffIds.remove(member.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _ruleType,
                decoration: InputDecoration(labelText: context.t('Rule type')),
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
                  if (value != null) {
                    setState(() => _ruleType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _LabeledTextField(
                label: context.t('Value'),
                controller: _valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _DateFieldButton(
                label: context.t('Effective from'),
                value: _effectiveFrom,
                onTap: () async {
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
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('Cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
          ),
          child: Text(context.t('Save Override')),
        ),
      ],
    );
  }
}
