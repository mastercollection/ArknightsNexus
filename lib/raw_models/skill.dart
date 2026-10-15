import 'raw_helpers.dart';

class RawSkillTable {
  const RawSkillTable({this.skills = const {}});

  final Map<String, RawSkillEntry> skills;

  factory RawSkillTable.fromJson(Map<String, Object?> json) {
    return RawSkillTable(
      skills: json.map(
        (key, value) => MapEntry(key, RawSkillEntry.fromJson(rawMap(value))),
      ),
    );
  }
}

class RawSkillEntry {
  const RawSkillEntry({
    this.skillId,
    this.iconId,
    this.levels = const [],
  });

  final String? skillId;
  final String? iconId;
  final List<RawSkillLevel> levels;

  factory RawSkillEntry.fromJson(Map<String, Object?> json) {
    return RawSkillEntry(
      skillId: rawOptString(json, 'skillId'),
      iconId: rawOptString(json, 'iconId'),
      levels: rawListOf(json['levels'], RawSkillLevel.fromJson),
    );
  }
}

class RawSkillLevel {
  const RawSkillLevel({
    required this.name,
    this.description,
    this.rangeId,
    this.skillType,
    this.spData,
    this.duration,
    this.blackboard,
  });

  final String name;
  final String? description;
  final String? rangeId;
  final String? skillType;
  final RawSpData? spData;
  final double? duration;
  final List<RawBlackboard>? blackboard;

  factory RawSkillLevel.fromJson(Map<String, Object?> json) {
    final spData = json['spData'];
    return RawSkillLevel(
      name: rawString(json, 'name'),
      description: rawOptString(json, 'description'),
      rangeId: rawOptString(json, 'rangeId'),
      skillType: rawOptString(json, 'skillType'),
      spData: spData is Map ? RawSpData.fromJson(rawMap(spData)) : null,
      duration: rawOptDouble(json, 'duration'),
      // Tauri: null → None, `{}` → Some([]), array → Some(list).
      blackboard: json['blackboard'] == null
          ? null
          : rawListOf(json['blackboard'], RawBlackboard.fromJson),
    );
  }
}

class RawSpData {
  const RawSpData({
    required this.spType,
    required this.spCost,
    required this.initSp,
  });

  /// Either an int (legacy numeric enum) or a String
  /// (`INCREASE_WITH_TIME` ...). Mirrors Tauri `RawSpTypeValue`.
  final Object? spType;
  final double spCost;
  final double initSp;

  factory RawSpData.fromJson(Map<String, Object?> json) {
    final spType = json['spType'];
    return RawSpData(
      spType: spType is String || spType is int ? spType : null,
      spCost: rawDouble(json, 'spCost'),
      initSp: rawDouble(json, 'initSp'),
    );
  }
}
