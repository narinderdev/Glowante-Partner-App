part of 'owner_profile_operations_screen.dart';

class _GoodsReceiptNoteFormView extends StatefulWidget {
  const _GoodsReceiptNoteFormView({
    required this.branchId,
    required this.onBack,
    required this.onSubmit,
    this.prefilledPoId,
  });

  final int branchId;
  final VoidCallback onBack;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;
  final int? prefilledPoId;

  @override
  State<_GoodsReceiptNoteFormView> createState() =>
      _GoodsReceiptNoteFormViewState();
}

class _GoodsReceiptNoteFormViewState extends State<_GoodsReceiptNoteFormView> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receivedByController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _purchaseOrders = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _poLineOptions = const <Map<String, dynamic>>[];
  List<_GrnLineInput> _lines = <_GrnLineInput>[_GrnLineInput()];
  int? _selectedPoId;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  String? _submitError;
  bool _isLoadingOptions = true;
  bool _isLoadingLines = false;
  bool _isSaving = false;
List<Map<String, dynamic>> _vendors = const <Map<String, dynamic>>[];
  bool get _isPoLocked => widget.prefilledPoId != null;

  @override
  void initState() {
    super.initState();
    _selectedPoId = widget.prefilledPoId;
    _loadPurchaseOrders();
  }
  String _poDropdownLabel(Map<String, dynamic> po) {
  final poNumber = _firstText(
    po,
    const ['poNumber', 'poId', 'id'],
    fallback: context.t('Purchase Order'),
  );

  final vendor = _vendorDisplayLabel(po, _vendors);

  return vendor == 'N/A' ? poNumber : '$poNumber - $vendor';
}
  // Future<void> _loadPurchaseOrders() async {
  //   final response = await _apiService.getPurchaseOrders(widget.branchId);
  //   if (!mounted) return;
  //   setState(() {
  //     _purchaseOrders = _recordList(response);
  //     _isLoadingOptions = false;
  //   });
  //   if (_selectedPoId != null) {
  //     await _loadPoLines(_selectedPoId!);
  //   }
  // }

Future<void> _loadPurchaseOrders() async {
  final results = await Future.wait<Map<String, dynamic>>([
    _apiService.getPurchaseOrders(widget.branchId),
    _apiService.getBranchVendors(widget.branchId),
  ]);

  if (!mounted) return;

  setState(() {
    _purchaseOrders = _recordList(results[0]);
    _vendors = _recordList(results[1]);
    _isLoadingOptions = false;
  });

  if (_selectedPoId != null) {
    await _loadPoLines(_selectedPoId!);
  }
}
  Future<void> _loadPoLines(int poId) async {
    setState(() => _isLoadingLines = true);
    final response = await _apiService.getPurchaseOrderDetails(
      branchId: widget.branchId,
      poId: poId,
    );
    final detail = _detailMap(response);
    final lineOptions = _recordList(detail['lines'] ?? detail['items']);
    final lines = lineOptions
        .map((line) => _GrnLineInput.fromPurchaseOrderLine(line))
        .toList();
    if (!mounted) return;
    for (final line in _lines) {
      line.dispose();
    }
    setState(() {
      _poLineOptions = lineOptions;
      _lines = lines.isEmpty ? <_GrnLineInput>[_GrnLineInput()] : lines;
      _isLoadingLines = false;
    });
  }

  void _addLine() {
    if (!_canAddLine) {
      Fluttertoast.showToast(
        msg: context.t('All purchase order items are already added'),
      );
      return;
    }
    final selectedPoLineIds = _selectedPoLineIds();
    Map<String, dynamic>? nextOption;
    for (final option in _poLineOptions) {
      final poLineId = _toInt(option['id'] ?? option['poLineId']);
      if (poLineId != null && !selectedPoLineIds.contains(poLineId)) {
        nextOption = option;
        break;
      }
    }
    if (nextOption == null) {
      Fluttertoast.showToast(
        msg: context.t('All purchase order items are already added'),
      );
      return;
    }
    setState(() {
      _lines = <_GrnLineInput>[
        ..._lines,
        _GrnLineInput.fromPurchaseOrderLine(nextOption!),
      ];
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final next = List<_GrnLineInput>.from(_lines);
    next.removeAt(index).dispose();
    setState(() => _lines = next);
  }

  int _remainingToReceive(_GrnLineInput line) {
    final remaining = line.orderedQty - line.receivedSoFarQty;
    return remaining < 0 ? 0 : remaining;
  }

  Set<int> _selectedPoLineIds({int? excludeIndex}) {
    final ids = <int>{};
    for (var index = 0; index < _lines.length; index++) {
      if (excludeIndex != null && index == excludeIndex) continue;
      final poLineId = _lines[index].poLineId;
      if (poLineId != null) ids.add(poLineId);
    }
    return ids;
  }

  bool get _canAddLine =>
      _poLineOptions.isNotEmpty && _lines.length < _poLineOptions.length;

  Future<void> _submit() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
      _submitError = null;
    });

    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(
        msg: context.t('Please fix the highlighted fields'),
      );
      return;
    }
    if (_selectedPoId == null) {
      Fluttertoast.showToast(msg: context.t('PO is required'));
      return;
    }
    for (final line in _lines) {
      if ((line.poLineId == null && line.itemId == null) ||
          (_toInt(line.receivedQtyController.text) ?? 0) <= 0) {
        Fluttertoast.showToast(
            msg: context.t('Each line requires poLine/item and received qty'));
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      final receivedBy = _receivedByController.text.trim();
      await widget.onSubmit(<String, dynamic>{
        'poId': _selectedPoId,
        'receivedBy': receivedBy,
        'receivedByUserId': receivedBy,
        'notes': _notesController.text.trim(),
        'lines': _lines
            .map(
              (line) => <String, dynamic>{
                'poLineId': line.poLineId,
                'itemId': line.itemId,
                'orderedQty': line.orderedQty,
                'receivedQty': _toInt(line.receivedQtyController.text) ?? 0,
                'returnQty': _toInt(line.returnQtyController.text) ?? 0,
                'returnReason': line.returnReasonController.text.trim(),
              },
            )
            .toList(),
      });
    } catch (error) {
      if (!mounted) return;
      final message = extractErrorMessage(
        error,
        fallback: context.t('Unable to save GRN. Please try again.'),
      );
      setState(() {
        _submitError = message;
      });
      Fluttertoast.showToast(msg: message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _receivedByController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: context.t('Create GRN'),
      onBack: widget.onBack,
      child: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: _autoValidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('grn-po-$_selectedPoId'),
                    initialValue: _selectedPoId,
                    decoration:
                        InputDecoration(labelText: context.t('Purchase Order')),
                    isExpanded: true,
                    menuMaxHeight: 260,
                    items: _purchaseOrders
                        .map(
                          (po) => DropdownMenuItem<int>(
                            value: _toInt(po['id'] ?? po['poId']),
                            // child: _dropdownMenuText(
                            //   _firstText(
                            //     po,
                            //     const ['poNumber', 'poId', 'id'],
                            //     fallback: context.t('Purchase Order'),
                            //   ),
                            // ),
                            child: _dropdownMenuText(_poDropdownLabel(po)),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? context.t('PO is required') : null,
                    onChanged: _isPoLocked
                        ? null
                        : (value) {
                            _clearSubmitError();
                            setState(() => _selectedPoId = value);
                            if (value != null) {
                              _loadPoLines(value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _receivedByController,
                    decoration:
                        InputDecoration(labelText: context.t('Received By')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Received By is required')
                        : null,
                    onChanged: (_) {
                      _clearSubmitError();
                      if (_autoValidateMode != AutovalidateMode.disabled) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    maxLength: 120,
                    controller: _notesController,
                    maxLines: 1,
                    decoration: InputDecoration(labelText: context.t('Notes')),
                    onChanged: (_) => _clearSubmitError(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('Item Lines'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_canAddLine)
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add),
                          label: Text(context.t('Add Line')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingLines)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._lines.asMap().entries.map((entry) {
                      final index = entry.key;
                      final line = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5F2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: line.itemLabel,
                              enabled: false,
                              decoration:
                                  InputDecoration(labelText: context.t('Item')),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: line.orderedQty.toString(),
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: context.t('Ordered Qty'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              maxLength: 15,
                              controller: line.receivedQtyController,
                              inputFormatters: _integerInputFormatters(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.t('Received Qty'),
                                helperText:
                                    '${_remainingToReceive(line)} ${context.t('left')}',
                              ),
                              validator: (value) {
                                final qty = _toInt(value);
                                if (qty == null || qty <= 0) {
                                  return context.t('Received Qty is required');
                                }
                                final remaining = _remainingToReceive(line);
                                if (qty > remaining) {
                                  return context.t(
                                    "Can't be greater than $remaining",
                                  );
                                }
                                return null;
                              },
                              onChanged: (_) {
                                _clearSubmitError();
                                if (_autoValidateMode !=
                                    AutovalidateMode.disabled) {
                                  _formKey.currentState?.validate();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              maxLength: 15,
                              controller: line.returnQtyController,
                              inputFormatters: _integerInputFormatters(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.t('Return Qty'),
                              ),
                              validator: (value) {
                                final qty = _toInt(value) ?? 0;
                                if (qty < 0) {
                                  return context.t('Must be >= 0');
                                }
                                return null;
                              },
                              onChanged: (_) {
                                _clearSubmitError();
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              maxLength: 120,
                              controller: line.returnReasonController,
                              decoration: InputDecoration(
                                labelText: context.t('Return Reason'),
                              ),
                              validator: (value) {
                                final returnQty =
                                    _toInt(line.returnQtyController.text) ?? 0;
                                if (returnQty > 0 &&
                                    _stringValue(value).isEmpty) {
                                  return context.t('Return Reason is required');
                                }
                                return null;
                              },
                              onChanged: (_) {
                                _clearSubmitError();
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _lines.length == 1
                                    ? null
                                    : () => _removeLine(index),
                                child: Text(context.t('Remove')),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE57373)),
                      ),
                      child: Text(
                        _submitError!,
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _isSaving
                            ? context.t('Saving...')
                            : context.t('Save GRN'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _clearSubmitError() {
    if (_submitError == null) return;
    setState(() => _submitError = null);
  }
}

class _GrnLineInput {
  _GrnLineInput({
    this.poLineId,
    this.itemId,
    this.itemLabel = '',
    this.orderedQty = 0,
    this.receivedSoFarQty = 0,
    String receivedQty = '',
    String returnQty = '',
    String returnReason = '',
  })  : receivedQtyController = TextEditingController(text: receivedQty),
        returnQtyController = TextEditingController(text: returnQty),
        returnReasonController = TextEditingController(text: returnReason);

  factory _GrnLineInput.fromPurchaseOrderLine(Map<String, dynamic> line) {
    return _GrnLineInput(
      poLineId: _toInt(line['id'] ?? line['poLineId']),
      itemId: _toInt(line['itemId'] ?? line['inventoryItemId']),
      itemLabel: _firstText(
        line,
        const ['itemName', 'name', 'title'],
        fallback: 'Item',
      ),
      orderedQty: _toInt(line['orderedQty'] ?? line['quantity']) ?? 0,
      receivedSoFarQty: _toInt(line['receivedQty']) ?? 0,
    );
  }

  int? poLineId;
  int? itemId;
  String itemLabel;
  int orderedQty;
  int receivedSoFarQty;
  final TextEditingController receivedQtyController;
  final TextEditingController returnQtyController;
  final TextEditingController returnReasonController;

  void dispose() {
    receivedQtyController.dispose();
    returnQtyController.dispose();
    returnReasonController.dispose();
  }
}
