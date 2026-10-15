Map<String, Object?> rawMap(Object? value) {
  // Upstream Arknights data serializes empty maps as an empty array `[]`, so
  // treat any non-map (including `[]` and null) as an empty map.
  if (value is! Map) {
    return <String, Object?>{};
  }
  return Map<String, Object?>.from(value);
}

Map<String, T> rawMapOf<T>(
  Object? value,
  T Function(Map<String, Object?> json) convert,
) {
  return rawMap(value).map(
    (key, entry) => MapEntry(key, convert(rawMap(entry))),
  );
}

List<T> rawListOf<T>(
  Object? value,
  T Function(Map<String, Object?> json) convert,
) {
  // Upstream Arknights data serializes empty arrays as an empty object `{}`,
  // so treat any non-list (including `{}` and null) as an empty list. Mirrors
  // the Tauri `deserialize_vec_or_empty_object` helpers.
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => convert(rawMap(entry))).toList();
}

List<String> rawStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList();
}

String rawString(
  Map<String, Object?> json,
  String key, {
  String defaultValue = '',
}) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  return value.toString();
}

int rawInt(Map<String, Object?> json, String key, {int defaultValue = 0}) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return num.tryParse(value.trim())?.toInt() ?? defaultValue;
  }
  return defaultValue;
}

/// Parses a value that may be a number or a prefixed enum string such as
/// `TIER_5` or `PHASE_2`, returning the trailing integer. Mirrors the Tauri
/// `parse_rarity` / `parse_phase_value` helpers. Upstream Arknights data uses
/// strings for some fields that were previously plain numbers.
int rawEnumInt(
  Map<String, Object?> json,
  String key, {
  required String prefix,
  int defaultValue = 0,
}) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    final digits =
        trimmed.startsWith(prefix) ? trimmed.substring(prefix.length) : trimmed;
    return int.tryParse(digits) ?? defaultValue;
  }
  return defaultValue;
}

double rawDouble(
  Map<String, Object?> json,
  String key, {
  double defaultValue = 0,
}) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return num.tryParse(value.trim())?.toDouble() ?? defaultValue;
  }
  return defaultValue;
}

bool rawBool(
  Map<String, Object?> json,
  String key, {
  bool defaultValue = false,
}) {
  final value = json[key];
  if (value == null) {
    return defaultValue;
  }
  return value as bool;
}

class RawCost {
  const RawCost({
    required this.id,
    required this.count,
    required this.type,
  });

  final String id;
  final double count;
  final String type;

  factory RawCost.fromJson(Map<String, Object?> json) {
    return RawCost(
      id: rawString(json, 'id'),
      count: rawDouble(json, 'count'),
      type: rawString(json, 'type'),
    );
  }
}

class RawBlackboard {
  const RawBlackboard({
    required this.key,
    this.value,
    this.valueStr,
  });

  final String key;
  final double? value;
  final String? valueStr;

  factory RawBlackboard.fromJson(Map<String, Object?> json) {
    final rawValue = json['value'];
    return RawBlackboard(
      key: rawString(json, 'key'),
      value: rawValue is num
          ? rawValue.toDouble()
          : rawValue is String
              ? num.tryParse(rawValue.trim())?.toDouble()
              : null,
      valueStr: json['valueStr']?.toString(),
    );
  }
}

class RawUnlockCond {
  const RawUnlockCond({
    required this.phase,
    required this.level,
  });

  final int phase;
  final int level;

  factory RawUnlockCond.fromJson(Map<String, Object?> json) {
    return RawUnlockCond(
      phase: rawPhaseValue(json['phase']),
      level: rawLevelValue(json['level']),
    );
  }
}

/// Compares strings like Rust `str::cmp` (UTF-8 byte order, equivalent to
/// Unicode code point order). Dart's `String.compareTo` compares UTF-16 code
/// units, which orders supplementary-plane characters differently.
int compareRustStrings(String left, String right) {
  final l = left.runes.iterator;
  final r = right.runes.iterator;
  while (true) {
    final hasLeft = l.moveNext();
    final hasRight = r.moveNext();
    if (!hasLeft || !hasRight) {
      return hasLeft == hasRight ? 0 : (hasLeft ? 1 : -1);
    }
    final diff = l.current - r.current;
    if (diff != 0) {
      return diff < 0 ? -1 : 1;
    }
  }
}

/// Mirrors Tauri `parse_phase_value`: numbers are used as-is, strings must be
/// `PHASE_<n>` (anything else resolves to 0).
int rawPhaseValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('PHASE_')) {
      return 0;
    }
    return int.tryParse(trimmed.substring('PHASE_'.length)) ?? 0;
  }
  return 0;
}

/// Mirrors Tauri `parse_level_value`: numbers are used as-is, strings are
/// parsed as integers after trimming (anything else resolves to 0).
int rawLevelValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

/// Returns the value as a string, or null when absent. Mirrors serde
/// `Option<String>` (an explicit empty string stays `""`).
String? rawOptString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value?.toString();
}

/// Returns a list for array values and null otherwise. Mirrors the Tauri
/// `Option<Vec<T>>` fields (`null` / missing / empty object → None).
List<T>? rawOptListOf<T>(
  Object? value,
  T Function(Map<String, Object?> json) convert,
) {
  if (value is! List) {
    return null;
  }
  return value.map((entry) => convert(rawMap(entry))).toList();
}

/// Parses an optional numeric value (number or numeric string).
double? rawOptDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return num.tryParse(value.trim())?.toDouble();
  }
  return null;
}
