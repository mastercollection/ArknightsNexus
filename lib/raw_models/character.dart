import 'raw_helpers.dart';

class RawCharacterTable {
  const RawCharacterTable({this.characters = const {}});

  final Map<String, RawCharacterEntry> characters;

  factory RawCharacterTable.fromJson(Map<String, Object?> json) {
    return RawCharacterTable(
      characters: json.map(
        (key, value) =>
            MapEntry(key, RawCharacterEntry.fromJson(rawMap(value))),
      ),
    );
  }
}

class RawCharacterEntry {
  const RawCharacterEntry({
    required this.name,
    this.description,
    this.appellation = '',
    this.canUseGeneralPotentialItem = false,
    this.isNotObtainable = false,
    this.isSpChar = false,
    required this.profession,
    this.subProfessionId = '',
    required this.rarity,
    this.position = '',
    this.tagList = const [],
    this.itemUsage,
    this.itemDesc,
    this.itemObtainApproach,
    this.displayNumber,
    this.groupId,
    this.nationId,
    this.teamId,
    this.traitField,
    this.phases = const [],
    this.skills = const [],
    this.talents,
    this.potentialRanks = const [],
    this.allSkillLvlup = const [],
    this.displayTokenIds = const [],
  });

  final String name;
  final String? description;
  final String appellation;
  final bool canUseGeneralPotentialItem;
  final bool isNotObtainable;
  final bool isSpChar;
  final String profession;
  final String subProfessionId;
  final int rarity;
  final String position;
  final List<String> tagList;
  final String? itemUsage;
  final String? itemDesc;
  final String? itemObtainApproach;
  final String? displayNumber;
  final String? groupId;
  final String? nationId;
  final String? teamId;

  /// Upstream `trait` (a reserved word in neither language, but kept as
  /// `traitField` to mirror the Tauri raw model).
  final RawTrait? traitField;
  final List<RawPhase> phases;
  final List<RawSkillReference> skills;
  final List<RawTalent>? talents;
  final List<RawPotentialRank> potentialRanks;
  final List<RawAllSkillLvlup> allSkillLvlup;

  /// Keys of the upstream `displayTokenDict`: the summons (`TOKEN` entries
  /// of the same table) the game lists for this operator, in upstream order.
  final List<String> displayTokenIds;

  factory RawCharacterEntry.fromJson(Map<String, Object?> json) {
    final trait = json['trait'];
    return RawCharacterEntry(
      name: rawString(json, 'name'),
      description: rawOptString(json, 'description'),
      appellation: rawString(json, 'appellation'),
      canUseGeneralPotentialItem: rawBool(json, 'canUseGeneralPotentialItem'),
      isNotObtainable: rawBool(json, 'isNotObtainable'),
      isSpChar: rawBool(json, 'isSpChar'),
      profession: rawString(json, 'profession'),
      subProfessionId: rawString(json, 'subProfessionId'),
      rarity: rawEnumInt(json, 'rarity', prefix: 'TIER_'),
      position: rawString(json, 'position'),
      tagList: rawStringList(json['tagList']),
      itemUsage: rawOptString(json, 'itemUsage'),
      itemDesc: rawOptString(json, 'itemDesc'),
      itemObtainApproach: rawOptString(json, 'itemObtainApproach'),
      displayNumber: rawOptString(json, 'displayNumber'),
      groupId: rawOptString(json, 'groupId'),
      nationId: rawOptString(json, 'nationId'),
      teamId: rawOptString(json, 'teamId'),
      traitField: trait is Map ? RawTrait.fromJson(rawMap(trait)) : null,
      phases: rawListOf(json['phases'], RawPhase.fromJson),
      skills: rawListOf(json['skills'], RawSkillReference.fromJson),
      talents: rawOptListOf(json['talents'], RawTalent.fromJson),
      potentialRanks:
          rawListOf(json['potentialRanks'], RawPotentialRank.fromJson),
      allSkillLvlup:
          rawListOf(json['allSkillLvlup'], RawAllSkillLvlup.fromJson),
      displayTokenIds: rawMap(json['displayTokenDict']).keys.toList(),
    );
  }
}

class RawPhase {
  const RawPhase({
    required this.characterPrefabKey,
    this.rangeId,
    required this.maxLevel,
    this.attributesKeyFrames = const [],
    this.evolveCost,
  });

  final String characterPrefabKey;
  final String? rangeId;
  final int maxLevel;
  final List<RawKeyFrame> attributesKeyFrames;
  final List<RawCost>? evolveCost;

  factory RawPhase.fromJson(Map<String, Object?> json) {
    return RawPhase(
      characterPrefabKey: rawString(json, 'characterPrefabKey'),
      rangeId: rawOptString(json, 'rangeId'),
      maxLevel: rawInt(json, 'maxLevel'),
      attributesKeyFrames:
          rawListOf(json['attributesKeyFrames'], RawKeyFrame.fromJson),
      evolveCost: rawOptListOf(json['evolveCost'], RawCost.fromJson),
    );
  }
}

class RawKeyFrame {
  const RawKeyFrame({
    required this.level,
    required this.data,
  });

  final int level;
  final RawAttributeData data;

  factory RawKeyFrame.fromJson(Map<String, Object?> json) {
    return RawKeyFrame(
      level: rawInt(json, 'level'),
      data: RawAttributeData.fromJson(rawMap(json['data'])),
    );
  }
}

/// Attribute values are kept as doubles (Tauri `RawNumberValue`) and rounded
/// by the normalizer, never truncated.
class RawAttributeData {
  const RawAttributeData({
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.magicResistance,
    required this.cost,
    required this.blockCnt,
    required this.baseAttackTime,
    required this.respawnTime,
    required this.hpRecoveryPerSec,
  });

  final double maxHp;
  final double atk;
  final double def;
  final double magicResistance;
  final double cost;
  final double blockCnt;
  final double baseAttackTime;
  final double respawnTime;
  final double hpRecoveryPerSec;

  factory RawAttributeData.fromJson(Map<String, Object?> json) {
    return RawAttributeData(
      maxHp: rawDouble(json, 'maxHp'),
      atk: rawDouble(json, 'atk'),
      def: rawDouble(json, 'def'),
      magicResistance: rawDouble(json, 'magicResistance'),
      cost: rawDouble(json, 'cost'),
      blockCnt: rawDouble(json, 'blockCnt'),
      baseAttackTime: rawDouble(json, 'baseAttackTime'),
      respawnTime: rawDouble(json, 'respawnTime'),
      hpRecoveryPerSec: rawDouble(json, 'hpRecoveryPerSec'),
    );
  }
}

class RawSkillReference {
  const RawSkillReference({
    required this.skillId,
    this.levelUpCostCond = const [],
    this.unlockCond = const RawUnlockCond(phase: 0, level: 0),
    this.overrideTokenKey,
  });

  final String? skillId;
  final List<RawLevelUpCostCond> levelUpCostCond;
  final RawUnlockCond unlockCond;

  /// The summon (token id) this skill deploys instead of the operator's
  /// default one; null when the skill does not change it.
  final String? overrideTokenKey;

  factory RawSkillReference.fromJson(Map<String, Object?> json) {
    return RawSkillReference(
      skillId: rawOptString(json, 'skillId'),
      overrideTokenKey: rawOptString(json, 'overrideTokenKey'),
      levelUpCostCond:
          rawListOf(json['levelUpCostCond'], RawLevelUpCostCond.fromJson),
      unlockCond: RawUnlockCond.fromJson(rawMap(json['unlockCond'])),
    );
  }
}

class RawLevelUpCostCond {
  const RawLevelUpCostCond({
    required this.unlockCond,
    required this.lvlUpTime,
    this.levelUpCost,
  });

  final RawUnlockCond unlockCond;
  final double lvlUpTime;
  final List<RawCost>? levelUpCost;

  factory RawLevelUpCostCond.fromJson(Map<String, Object?> json) {
    return RawLevelUpCostCond(
      unlockCond: RawUnlockCond.fromJson(rawMap(json['unlockCond'])),
      lvlUpTime: rawDouble(json, 'lvlUpTime'),
      levelUpCost: rawOptListOf(json['levelUpCost'], RawCost.fromJson),
    );
  }
}

class RawAllSkillLvlup {
  const RawAllSkillLvlup({required this.unlockCond, this.lvlUpCost});

  final RawUnlockCond unlockCond;
  final List<RawCost>? lvlUpCost;

  factory RawAllSkillLvlup.fromJson(Map<String, Object?> json) {
    return RawAllSkillLvlup(
      unlockCond: RawUnlockCond.fromJson(rawMap(json['unlockCond'])),
      lvlUpCost: rawOptListOf(json['lvlUpCost'], RawCost.fromJson),
    );
  }
}

class RawPotentialRank {
  const RawPotentialRank({required this.description});

  final String description;

  factory RawPotentialRank.fromJson(Map<String, Object?> json) {
    return RawPotentialRank(description: rawString(json, 'description'));
  }
}

class RawTrait {
  const RawTrait({this.candidates = const []});

  final List<RawTraitCandidate> candidates;

  factory RawTrait.fromJson(Map<String, Object?> json) {
    return RawTrait(
      candidates: rawListOf(json['candidates'], RawTraitCandidate.fromJson),
    );
  }
}

class RawTraitCandidate {
  const RawTraitCandidate({
    required this.unlockCondition,
    required this.requiredPotentialRank,
    this.blackboard = const [],
    this.overrideDescripton,
    this.prefabKey,
    this.rangeId,
  });

  final RawUnlockCond unlockCondition;
  final double requiredPotentialRank;
  final List<RawBlackboard> blackboard;

  /// Upstream field name keeps the typo (`overrideDescripton`).
  final String? overrideDescripton;
  final String? prefabKey;
  final String? rangeId;

  factory RawTraitCandidate.fromJson(Map<String, Object?> json) {
    return RawTraitCandidate(
      unlockCondition: RawUnlockCond.fromJson(rawMap(json['unlockCondition'])),
      requiredPotentialRank: rawDouble(json, 'requiredPotentialRank'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
      overrideDescripton: rawOptString(json, 'overrideDescripton'),
      prefabKey: rawOptString(json, 'prefabKey'),
      rangeId: rawOptString(json, 'rangeId'),
    );
  }
}

class RawTalent {
  const RawTalent({this.candidates});

  final List<RawTalentCandidate>? candidates;

  factory RawTalent.fromJson(Map<String, Object?> json) {
    return RawTalent(
      candidates: rawOptListOf(json['candidates'], RawTalentCandidate.fromJson),
    );
  }
}

class RawTalentCandidate {
  const RawTalentCandidate({
    required this.unlockCondition,
    required this.requiredPotentialRank,
    this.prefabKey,
    this.name,
    this.description,
    this.rangeId,
    this.blackboard = const [],
  });

  final RawUnlockCond unlockCondition;
  final double requiredPotentialRank;
  final String? prefabKey;
  final String? name;
  final String? description;
  final String? rangeId;
  final List<RawBlackboard> blackboard;

  factory RawTalentCandidate.fromJson(Map<String, Object?> json) {
    return RawTalentCandidate(
      unlockCondition: RawUnlockCond.fromJson(rawMap(json['unlockCondition'])),
      requiredPotentialRank: rawDouble(json, 'requiredPotentialRank'),
      prefabKey: rawOptString(json, 'prefabKey'),
      name: rawOptString(json, 'name'),
      description: rawOptString(json, 'description'),
      rangeId: rawOptString(json, 'rangeId'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
    );
  }
}
