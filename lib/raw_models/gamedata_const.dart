import 'raw_helpers.dart';

class RawGameDataConst {
  const RawGameDataConst({
    this.termDescriptionDict = const {},
    this.maxLevel = const [],
    this.characterExpMap = const [],
    this.characterUpgradeCostMap = const [],
    this.evolveGoldCost = const [],
  });

  final Map<String, RawTermDescription> termDescriptionDict;

  /// Max level per rarity tier (index = rarity - 1) and elite phase.
  final List<List<int>> maxLevel;
  final List<List<int>> characterExpMap;
  final List<List<int>> characterUpgradeCostMap;

  /// Evolve LMD cost per rarity tier (index = rarity - 1); `-1` = n/a.
  final List<List<int>> evolveGoldCost;

  factory RawGameDataConst.fromJson(Map<String, Object?> json) {
    return RawGameDataConst(
      termDescriptionDict: rawMapOf(
        json['termDescriptionDict'],
        RawTermDescription.fromJson,
      ),
      maxLevel: _intMatrix(json['maxLevel']),
      characterExpMap: _intMatrix(json['characterExpMap']),
      characterUpgradeCostMap: _intMatrix(json['characterUpgradeCostMap']),
      evolveGoldCost: _intMatrix(json['evolveGoldCost']),
    );
  }

  /// Port of Tauri `RawGameDataConst::into_term_descriptions`: trimmed
  /// descriptions, empty ones dropped.
  Map<String, String> termDescriptions() {
    final result = <String, String>{};
    for (final entry in termDescriptionDict.entries) {
      final description = entry.value.description.trim();
      if (description.isNotEmpty) {
        result[entry.key] = description;
      }
    }
    return result;
  }
}

class RawTermDescription {
  const RawTermDescription({
    required this.termId,
    required this.termName,
    required this.description,
  });

  final String termId;
  final String termName;
  final String description;

  factory RawTermDescription.fromJson(Map<String, Object?> json) {
    return RawTermDescription(
      termId: rawString(json, 'termId'),
      termName: rawString(json, 'termName'),
      description: rawString(json, 'description'),
    );
  }
}

int _toInt(Object? entry) {
  if (entry is num) {
    return entry.toInt();
  }
  if (entry is String) {
    return num.tryParse(entry.trim())?.toInt() ?? 0;
  }
  return 0;
}

List<int> _ints(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_toInt).toList();
}

List<List<int>> _intMatrix(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_ints).toList();
}
