String formatAddressSummary(dynamic rawAddress) {
  if (rawAddress == null) return '';
  if (rawAddress is String) {
    final text = rawAddress.trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? '' : text;
  }
  if (rawAddress is! Map) return '';

  final address = Map<String, dynamic>.from(rawAddress);
  final parts = <String>[];
  final seenParts = <String>{};

  List<String> splitParts(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return const [];

    return text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'null')
        .toList();
  }

  bool startsWithParts(List<String> source, List<String> prefix) {
    if (prefix.isEmpty || source.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (source[index].toLowerCase() != prefix[index].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  void push(dynamic value, {bool preserveInternalDuplicates = false}) {
    for (final cleaned in splitParts(value)) {
      final key = cleaned.toLowerCase();
      if (preserveInternalDuplicates) {
        parts.add(cleaned);
        seenParts.add(key);
      } else if (seenParts.add(key)) {
        parts.add(cleaned);
      }
    }
  }

  final line1 =
      address['line1'] ?? address['addressLine1'] ?? address['buildingName'];
  final line2 = address['line2'] ?? address['addressLine2'];
  final line1Parts = splitParts(line1);
  final line2Parts = splitParts(line2);
  push(line1, preserveInternalDuplicates: true);
  if (line2Parts.length <= 1 || !startsWithParts(line1Parts, line2Parts)) {
    push(line2, preserveInternalDuplicates: true);
  }
  push(address['formattedAddress']);
  push(address['village']);
  push(address['district']);
  push(address['city']);
  push(address['state']);
  push(address['postalCode'] ?? address['pincode'] ?? address['zip']);
  push(address['country']);

  return parts.join(', ');
}
