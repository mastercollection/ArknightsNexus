import 'raw_helpers.dart';

/// `excel/enemy_handbook_table.json`: what the in-game enemy archive shows.
/// It does not list every enemy of `enemy_database` (alternate forms and
/// some stage-only enemies are missing).
class RawEnemyHandbookTable {
  const RawEnemyHandbookTable({
    this.enemyData = const {},
    this.levelInfoList = const [],
  });

  final Map<String, RawEnemyHandbookEntry> enemyData;

  /// The stat brackets behind the archive's letter grades.
  final List<RawEnemyLevelInfo> levelInfoList;

  factory RawEnemyHandbookTable.fromJson(Map<String, Object?> json) {
    return RawEnemyHandbookTable(
      enemyData: rawMapOf(json['enemyData'], RawEnemyHandbookEntry.fromJson),
      levelInfoList:
          rawListOf(json['levelInfoList'], RawEnemyLevelInfo.fromJson),
    );
  }
}

class RawEnemyHandbookEntry {
  const RawEnemyHandbookEntry({
    required this.enemyId,
    required this.enemyIndex,
    required this.sortId,
    required this.name,
    required this.enemyLevel,
    this.description,
    this.damageType = const [],
    this.abilityList = const [],
    this.hideInHandbook = false,
  });

  final String enemyId;

  /// Such as `B2`.
  final String enemyIndex;
  final int sortId;
  final String name;

  /// `NORMAL`, `ELITE` or `BOSS`.
  final String enemyLevel;
  final String? description;

  /// `PHYSIC`, `MAGIC`, `HEAL`, `NO_DAMAGE`, ...
  final List<String> damageType;
  final List<RawEnemyAbility> abilityList;
  final bool hideInHandbook;

  factory RawEnemyHandbookEntry.fromJson(Map<String, Object?> json) {
    return RawEnemyHandbookEntry(
      enemyId: rawString(json, 'enemyId'),
      enemyIndex: rawString(json, 'enemyIndex'),
      sortId: rawInt(json, 'sortId'),
      name: rawString(json, 'name'),
      enemyLevel: rawString(json, 'enemyLevel'),
      description: rawOptString(json, 'description'),
      damageType: rawStringList(json['damageType']),
      abilityList: rawListOf(json['abilityList'], RawEnemyAbility.fromJson),
      hideInHandbook: rawBool(json, 'hideInHandbook'),
    );
  }
}

class RawEnemyAbility {
  const RawEnemyAbility({required this.text, this.textFormat});

  final String text;

  /// `NORMAL`, `TITLE`, `SILENCE`, ...: how the archive styles the line.
  final String? textFormat;

  factory RawEnemyAbility.fromJson(Map<String, Object?> json) {
    return RawEnemyAbility(
      text: rawString(json, 'text'),
      textFormat: rawOptString(json, 'textFormat'),
    );
  }
}

class RawEnemyLevelInfo {
  const RawEnemyLevelInfo({
    required this.classLevel,
    required this.maxHp,
    required this.attack,
    required this.def,
    required this.magicRes,
  });

  /// Such as `S+`.
  final String classLevel;
  final RawStatBracket maxHp;
  final RawStatBracket attack;
  final RawStatBracket def;
  final RawStatBracket magicRes;

  factory RawEnemyLevelInfo.fromJson(Map<String, Object?> json) {
    return RawEnemyLevelInfo(
      classLevel: rawString(json, 'classLevel'),
      maxHp: RawStatBracket.fromJson(rawMap(json['maxHP'])),
      attack: RawStatBracket.fromJson(rawMap(json['attack'])),
      def: RawStatBracket.fromJson(rawMap(json['def'])),
      magicRes: RawStatBracket.fromJson(rawMap(json['magicRes'])),
    );
  }
}

class RawStatBracket {
  const RawStatBracket({required this.min, required this.max});

  final double min;

  /// -1 for no upper bound.
  final double max;

  factory RawStatBracket.fromJson(Map<String, Object?> json) {
    return RawStatBracket(
      min: rawDouble(json, 'min'),
      max: rawDouble(json, 'max'),
    );
  }
}
