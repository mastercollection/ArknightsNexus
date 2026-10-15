import 'raw_helpers.dart';

class RawBattleEquipTable {
  const RawBattleEquipTable({this.equips = const {}});

  final Map<String, RawBattleEquipEntry> equips;

  factory RawBattleEquipTable.fromJson(Map<String, Object?> json) {
    return RawBattleEquipTable(
      equips: json.map(
        (key, value) =>
            MapEntry(key, RawBattleEquipEntry.fromJson(rawMap(value))),
      ),
    );
  }
}

class RawBattleEquipEntry {
  const RawBattleEquipEntry({this.phases = const []});

  final List<RawBattleEquipPhase> phases;

  factory RawBattleEquipEntry.fromJson(Map<String, Object?> json) {
    return RawBattleEquipEntry(
      phases: rawListOf(json['phases'], RawBattleEquipPhase.fromJson),
    );
  }
}

class RawBattleEquipPhase {
  const RawBattleEquipPhase({
    required this.equipLevel,
    this.parts = const [],
    this.attributeBlackboard = const [],
  });

  final int equipLevel;
  final List<RawBattleEquipPart> parts;
  final List<RawBlackboard> attributeBlackboard;

  factory RawBattleEquipPhase.fromJson(Map<String, Object?> json) {
    return RawBattleEquipPhase(
      equipLevel: rawInt(json, 'equipLevel'),
      parts: rawListOf(json['parts'], RawBattleEquipPart.fromJson),
      attributeBlackboard: rawListOf(
        json['attributeBlackboard'],
        RawBlackboard.fromJson,
      ),
    );
  }
}

class RawBattleEquipPart {
  const RawBattleEquipPart({
    required this.target,
    this.traitCandidates = const [],
    this.talentCandidates = const [],
  });

  final String target;

  /// `overrideTraitDataBundle.candidates` (null / `{}` → empty).
  final List<RawBattleEquipTraitCandidate> traitCandidates;

  /// `addOrOverrideTalentDataBundle.candidates` (null / `{}` → empty).
  final List<RawBattleEquipTalentCandidate> talentCandidates;

  factory RawBattleEquipPart.fromJson(Map<String, Object?> json) {
    final traitBundle = rawMap(json['overrideTraitDataBundle']);
    final talentBundle = rawMap(json['addOrOverrideTalentDataBundle']);

    return RawBattleEquipPart(
      target: rawString(json, 'target'),
      traitCandidates: rawListOf(
        traitBundle['candidates'],
        RawBattleEquipTraitCandidate.fromJson,
      ),
      talentCandidates: rawListOf(
        talentBundle['candidates'],
        RawBattleEquipTalentCandidate.fromJson,
      ),
    );
  }
}

class RawBattleEquipTraitCandidate {
  const RawBattleEquipTraitCandidate({
    this.additionalDescription,
    required this.unlockCondition,
    required this.requiredPotentialRank,
    this.blackboard = const [],
    this.rangeId,
  });

  final String? additionalDescription;
  final RawUnlockCond unlockCondition;
  final double requiredPotentialRank;
  final List<RawBlackboard> blackboard;
  final String? rangeId;

  factory RawBattleEquipTraitCandidate.fromJson(Map<String, Object?> json) {
    return RawBattleEquipTraitCandidate(
      additionalDescription: rawOptString(json, 'additionalDescription'),
      unlockCondition: RawUnlockCond.fromJson(rawMap(json['unlockCondition'])),
      requiredPotentialRank: rawDouble(json, 'requiredPotentialRank'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
      rangeId: rawOptString(json, 'rangeId'),
    );
  }
}

class RawBattleEquipTalentCandidate {
  const RawBattleEquipTalentCandidate({
    this.upgradeDescription,
    required this.unlockCondition,
    required this.requiredPotentialRank,
    this.name,
    this.rangeId,
    this.blackboard = const [],
  });

  final String? upgradeDescription;
  final RawUnlockCond unlockCondition;
  final double requiredPotentialRank;
  final String? name;
  final String? rangeId;
  final List<RawBlackboard> blackboard;

  factory RawBattleEquipTalentCandidate.fromJson(Map<String, Object?> json) {
    return RawBattleEquipTalentCandidate(
      upgradeDescription: rawOptString(json, 'upgradeDescription'),
      unlockCondition: RawUnlockCond.fromJson(rawMap(json['unlockCondition'])),
      requiredPotentialRank: rawDouble(json, 'requiredPotentialRank'),
      name: rawOptString(json, 'name'),
      rangeId: rawOptString(json, 'rangeId'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
    );
  }
}
