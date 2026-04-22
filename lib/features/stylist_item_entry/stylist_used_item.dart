class StylistUsedItem {
  const StylistUsedItem({
    required this.name,
    required this.brand,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.code,
    required this.notes,
    required this.sourceLabel,
  });

  final String name;
  final String brand;
  final String category;
  final String quantity;
  final String unit;
  final String code;
  final String notes;
  final String sourceLabel;

  String get quantityLabel {
    if (unit.trim().isEmpty) return quantity.trim();
    return '${quantity.trim()} ${unit.trim()}';
  }

  String get subtitle {
    final parts = <String>[
      if (brand.trim().isNotEmpty) brand.trim(),
      if (category.trim().isNotEmpty) category.trim(),
      if (code.trim().isNotEmpty) 'Code: ${code.trim()}',
    ];
    return parts.join(' • ');
  }

  StylistUsedItem copyWith({
    String? name,
    String? brand,
    String? category,
    String? quantity,
    String? unit,
    String? code,
    String? notes,
    String? sourceLabel,
  }) {
    return StylistUsedItem(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      code: code ?? this.code,
      notes: notes ?? this.notes,
      sourceLabel: sourceLabel ?? this.sourceLabel,
    );
  }

  factory StylistUsedItem.fromScanCode(String code) {
    const catalog = <String, Map<String, String>>{
      '8901234567890': {
        'name': 'Keratin Repair Serum',
        'brand': 'Glowante Pro',
        'category': 'Hair Treatment',
        'unit': 'ml',
        'quantity': '15',
        'notes': 'Recommended after smoothing and repair services.',
      },
      '9780201379624': {
        'name': 'Hydra Glow Cleanser',
        'brand': 'Beauty Lab',
        'category': 'Skin Prep',
        'unit': 'ml',
        'quantity': '10',
        'notes': 'Use as a prep step before facial services.',
      },
      'QR-GLOWANTE-001': {
        'name': 'Vitamin C Polish Mask',
        'brand': 'Radiant Skin Co.',
        'category': 'Facial Mask',
        'unit': 'gm',
        'quantity': '20',
        'notes': 'Apply evenly and leave for 10 minutes.',
      },
    };

    final details = catalog[code.trim()];
    return StylistUsedItem(
      name: details?['name'] ?? 'Scanned Beauty Product',
      brand: details?['brand'] ?? 'Unmapped Brand',
      category: details?['category'] ?? 'Beauty Product',
      quantity: details?['quantity'] ?? '1',
      unit: details?['unit'] ?? 'unit',
      code: code.trim(),
      notes: details?['notes'] ?? 'Details added from camera scan.',
      sourceLabel: 'Camera scan',
    );
  }
}
