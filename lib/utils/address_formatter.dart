String formatAddressSummary(dynamic rawAddress) {
  if (rawAddress == null) return '';
  if (rawAddress is String) {
    final text = rawAddress.trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? '' : text;
  }
  if (rawAddress is! Map) return '';

  final address = Map<String, dynamic>.from(rawAddress);
  final parts = <String>[];

  void push(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return;

    for (final part in text.split(',')) {
      final cleaned = part.trim();
      if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') continue;
      parts.add(cleaned);
    }
  }

  push(address['line1'] ?? address['addressLine1'] ?? address['buildingName']);
  push(address['line2'] ?? address['addressLine2']);
  push(address['village']);
  push(address['district']);
  push(address['city']);
  push(address['state']);
  push(address['country']);
  push(address['postalCode'] ?? address['pincode'] ?? address['zip']);

  return parts.join(', ');
}
