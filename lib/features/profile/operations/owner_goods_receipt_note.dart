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
  List<_GrnLineInput> _lines = const <_GrnLineInput>[];
  int? _selectedPoId;
  bool _isLoadingOptions = true;
  bool _isLoadingLines = false;
  bool _isSaving = false;

  bool get _isPoLocked => widget.prefilledPoId != null;

  @override
  void initState() {
    super.initState();
    _selectedPoId = widget.prefilledPoId;
    _loadPurchaseOrders();
  }

  Future<void> _loadPurchaseOrders() async {
    final response = await _apiService.getPurchaseOrders(widget.branchId);
    if (!mounted) return;
    setState(() {
      _purchaseOrders = _recordList(response);
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
    final lines = _recordList(detail['lines'] ?? detail['items'])
        .map((line) => _GrnLineInput.fromPurchaseOrderLine(line))
        .toList();
    if (!mounted) return;
    setState(() {
      _lines = lines.isEmpty ? <_GrnLineInput>[_GrnLineInput()] : lines;
      _isLoadingLines = false;
    });
  }

  void _addLine() {
    setState(() {
      _lines = <_GrnLineInput>[..._lines, _GrnLineInput()];
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final next = List<_GrnLineInput>.from(_lines);
    next.removeAt(index).dispose();
    setState(() => _lines = next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPoId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('PO is required'))));
      return;
    }
    for (final line in _lines) {
      if ((line.poLineId == null && line.itemId == null) ||
          (_toInt(line.receivedQtyController.text) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.t('Each line requires poLine/item and received qty')),
          ),
        );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
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
      title: context.t('Add GRN'),
      onBack: widget.onBack,
      child: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('grn-po-$_selectedPoId'),
                    initialValue: _selectedPoId,
                    decoration:
                        InputDecoration(labelText: context.t('Purchase Order')),
                    items: _purchaseOrders
                        .map(
                          (po) => DropdownMenuItem<int>(
                            value: _toInt(po['id'] ?? po['poId']),
                            child: Text(
                              _firstText(
                                po,
                                const ['poId', 'id'],
                                fallback: context.t('Purchase Order'),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isPoLocked
                        ? null
                        : (value) {
                            setState(() => _selectedPoId = value);
                            if (value != null) {
                              _loadPoLines(value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _receivedByController,
                    decoration:
                        InputDecoration(labelText: context.t('Received By')),
                    validator: (value) => _stringValue(value).isEmpty
                        ? context.t('Received By is required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 1,
                    decoration: InputDecoration(labelText: context.t('Notes')),
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
                              controller: line.receivedQtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.t('Received Qty'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: line.returnQtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.t('Return Qty'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: line.returnReasonController,
                              decoration: InputDecoration(
                                labelText: context.t('Return Reason'),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _removeLine(index),
                                child: Text(context.t('Remove')),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
}

class _GrnLineInput {
  _GrnLineInput({
    this.poLineId,
    this.itemId,
    this.itemLabel = '',
    this.orderedQty = 0,
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
    );
  }

  int? poLineId;
  int? itemId;
  String itemLabel;
  int orderedQty;
  final TextEditingController receivedQtyController;
  final TextEditingController returnQtyController;
  final TextEditingController returnReasonController;

  void dispose() {
    receivedQtyController.dispose();
    returnQtyController.dispose();
    returnReasonController.dispose();
  }
}
