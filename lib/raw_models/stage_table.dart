import 'raw_helpers.dart';

class RawStageTable {
  const RawStageTable({this.stages = const {}});

  final Map<String, RawStageEntry> stages;

  factory RawStageTable.fromJson(Map<String, Object?> json) {
    return RawStageTable(
      stages: rawMapOf(json['stages'], RawStageEntry.fromJson),
    );
  }
}

class RawStageEntry {
  const RawStageEntry({
    required this.stageId,
    this.code,
    this.stageType = '',
    this.difficulty = '',
    this.diffGroup = '',
    this.levelId,
    this.zoneId = '',
    this.name,
    this.description,
    this.dangerLevel,
    this.apCost = 0,
    this.bossMark = false,
    this.displayDetailRewards = const [],
  });

  final String stageId;
  final String? code;

  /// `MAIN`, `ACTIVITY`, `CLIMB_TOWER`, `SUB`, `DAILY`, `CAMPAIGN`, ...
  final String stageType;

  /// `NORMAL`, `FOUR_STAR` (Challenge Mode, ids ending in `#f#`) or
  /// `SIX_STAR`.
  final String difficulty;

  /// `NONE`, `NORMAL`, `TOUGH`, `EASY` or `ALL` (the Adverse/Standard split of
  /// later mainline episodes).
  final String diffGroup;

  /// Path of the stage's level file under `gamedata/levels`, such as
  /// `Obt/Main/level_main_01-07`; null for story-only stages. Challenge Mode
  /// stages share the level of their normal stage.
  final String? levelId;
  final String zoneId;
  final String? name;
  final String? description;
  final String? dangerLevel;
  final int apCost;
  final bool bossMark;
  final List<RawStageReward> displayDetailRewards;

  factory RawStageEntry.fromJson(Map<String, Object?> json) {
    final dropInfo = rawMap(json['stageDropInfo']);
    return RawStageEntry(
      stageId: rawString(json, 'stageId'),
      code: json['code'] as String?,
      stageType: rawString(json, 'stageType'),
      difficulty: rawString(json, 'difficulty'),
      diffGroup: rawString(json, 'diffGroup'),
      levelId: rawOptString(json, 'levelId'),
      zoneId: rawString(json, 'zoneId'),
      name: rawOptString(json, 'name'),
      description: rawOptString(json, 'description'),
      dangerLevel: rawOptString(json, 'dangerLevel'),
      apCost: rawInt(json, 'apCost'),
      bossMark: rawBool(json, 'bossMark'),
      displayDetailRewards: rawListOf(
        dropInfo['displayDetailRewards'],
        RawStageReward.fromJson,
      ),
    );
  }
}

class RawStageReward {
  const RawStageReward({
    required this.type,
    required this.id,
    required this.dropType,
    required this.occPercent,
  });

  /// `MATERIAL`, `CHAR`, `CARD_EXP`, `DIAMOND`, `FURN`, ...
  final String type;
  final String id;

  /// `ONCE`, `NORMAL`, `ADDITIONAL`, `COMPLETE`, `SPECIAL`, ...
  final String dropType;

  /// `ALWAYS`, `ALMOST`, `USUAL`, `OFTEN`, `SOMETIMES`: a frequency label,
  /// not a rate.
  final String occPercent;

  factory RawStageReward.fromJson(Map<String, Object?> json) {
    return RawStageReward(
      type: rawString(json, 'type'),
      id: rawString(json, 'id'),
      dropType: rawString(json, 'dropType'),
      occPercent: rawString(json, 'occPercent'),
    );
  }
}
