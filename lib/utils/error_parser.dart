import 'dart:convert';

String extractErrorMessage(
  dynamic error, {
  String fallback = 'Something went wrong',
}) {
  final message = extractMessage(error, fallback: '').trim();
  return message.isNotEmpty ? message : fallback;
}

String extractMessage(
  dynamic data, {
  String fallback = 'Something went wrong',
}) {
  if (data is Exception || data is Error) {
    return extractMessage(data.toString(), fallback: fallback);
  }

  final message = _extractFromDynamic(data)?.trim();
  return (message != null && message.isNotEmpty) ? message : fallback;
}

String? _extractFromJsonString(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  String? candidate;

  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      final dynamic decoded = jsonDecode(trimmed);
      candidate = _extractFromDynamic(decoded);
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    } catch (_) {}
  }

  final jsonStart = trimmed.indexOf('{');
  if (jsonStart > 0) {
    final jsonString = trimmed.substring(jsonStart);
    if (jsonString.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(jsonString);
        candidate = _extractFromDynamic(decoded);
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      } catch (_) {}
    }
  }

  return null;
}

String? _extractFromDynamic(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final nested = _extractFromJsonString(trimmed);
    if (nested != null && nested.isNotEmpty) {
      return nested;
    }

    final cleaned = _stripKnownPrefixes(trimmed);
    return cleaned.isNotEmpty ? cleaned : trimmed;
  }

  if (value is Iterable) {
    for (final item in value) {
      final candidate = _extractFromDynamic(item);
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  if (value is Map) {
    final preferredKeys = [
      'message',
      'error',
      'errors',
      'detail',
      'description',
    ];
    for (final key in preferredKeys) {
      if (value.containsKey(key)) {
        final candidate = _extractFromDynamic(value[key]);
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    }

    for (final entry in value.entries) {
      final candidate = _extractFromDynamic(entry.value);
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  return _extractFromDynamic(value.toString());
}

String _stripKnownPrefixes(String value) {
  var cleaned = value;
  final patterns = <RegExp>[
    RegExp(r'^Exception:\s*', caseSensitive: false),
    RegExp(r'^[A-Za-z\s]*failed[A-Za-z\s]*:\s*', caseSensitive: false),
    RegExp(r'^[A-Za-z\s]*error[A-Za-z\s]*:\s*', caseSensitive: false),
    RegExp(r'^[A-Za-z\s]*exception[A-Za-z\s]*:\s*', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    cleaned = cleaned.replaceFirst(pattern, '');
  }

  return cleaned.trim();
}
