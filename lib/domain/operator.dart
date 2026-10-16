class OperatorSummary {
  const OperatorSummary({
    required this.id,
    required this.name,
    required this.rarity,
    required this.profession,
    required this.branch,
    this.teams = const [],
    this.nations = const [],
    this.groups = const [],
    this.baTags = const [],
    required this.thumbnailHue,
    this.releaseOrder = 0,
    this.unreleasedSource,
  });

  final String id;
  final String name;
  final int rarity;
  final String profession;
  final String branch;
  final List<String> teams;
  final List<String> nations;
  final List<String> groups;
  final List<String> baTags;
  final int thumbnailHue;

  /// Position of the operator in the region's `handbook_info_table`
  /// `handbookDict`, counted from 1, whose key order is the order operators
  /// were released in that region; higher is newer. 0 when the operator is
  /// not in the handbook. The snapshot keeps operators sorted by this,
  /// newest first. For an unreleased operator (see [unreleasedSource]) it
  /// is the position in the source region's handbook instead.
  final int releaseOrder;

  /// Region code (`en` or `cn`) whose official data this operator was
  /// copied from because the snapshot's own region has not released it yet;
  /// null for the region's own operators. Only the published snapshots
  /// (`tool/build_snapshots.dart`) contain such operators.
  final String? unreleasedSource;

  bool get isUnreleased => unreleasedSource != null;

  factory OperatorSummary.fromJson(Map<String, Object?> json) {
    return OperatorSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      rarity: _int(json['rarity']),
      profession: json['profession'] as String,
      branch: json['branch'] as String,
      teams: _strings(json['teams']),
      nations: _strings(json['nations']),
      groups: _strings(json['groups']),
      baTags: _strings(json['baTags']),
      thumbnailHue: _int(json['thumbnailHue']),
      releaseOrder: _optionalInt(json['releaseOrder']),
      unreleasedSource: json['unreleasedSource'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'rarity': rarity,
      'profession': profession,
      'branch': branch,
      'teams': teams,
      'nations': nations,
      'groups': groups,
      'baTags': baTags,
      'thumbnailHue': thumbnailHue,
      'releaseOrder': releaseOrder,
      if (unreleasedSource != null) 'unreleasedSource': unreleasedSource,
    };
  }
}

class OperatorDetail {
  const OperatorDetail({
    required this.id,
    required this.name,
    required this.codename,
    required this.rarity,
    required this.profession,
    required this.branch,
    this.teams = const [],
    this.nations = const [],
    this.groups = const [],
    this.baTags = const [],
    required this.thumbnailHue,
    this.releaseOrder = 0,
    this.unreleasedSource,
    required this.quote,
    this.tags = const [],
    this.traits = const [],
    this.talents = const [],
    this.potentials = const [],
    this.modules = const [],
    required this.archetypeDescription,
    this.eliteCaps = const [],
    this.eliteExpCosts = const [],
    this.eliteUpgradeGoldCosts = const [],
    this.eliteEvolveGoldCosts = const [],
    this.eliteEvolveCosts = const [],
    this.allSkillLevelUpCosts = const [],
    this.stats = const [],
    this.skills = const [],
    this.tokens = const [],
  });

  final String id;
  final String name;
  final String codename;
  final int rarity;
  final String profession;
  final String branch;
  final List<String> teams;
  final List<String> nations;
  final List<String> groups;
  final List<String> baTags;
  final int thumbnailHue;

  /// Release position; see [OperatorSummary.releaseOrder].
  final int releaseOrder;

  /// See [OperatorSummary.unreleasedSource].
  final String? unreleasedSource;

  bool get isUnreleased => unreleasedSource != null;

  final String quote;
  final List<String> tags;
  final List<OperatorTrait> traits;
  final List<OperatorTalent> talents;
  final List<OperatorPotential> potentials;
  final List<OperatorModule> modules;
  final String archetypeDescription;
  final List<int> eliteCaps;
  final List<List<int>> eliteExpCosts;
  final List<List<int>> eliteUpgradeGoldCosts;
  final List<int> eliteEvolveGoldCosts;
  final List<List<OperatorCost>> eliteEvolveCosts;
  final List<OperatorUpgradeCostStage> allSkillLevelUpCosts;
  final List<OperatorStatProgression> stats;
  final List<OperatorSkill> skills;

  /// The summons the game lists for this operator, in upstream order; empty
  /// for most operators and always for a summon itself.
  final List<OperatorToken> tokens;

  /// This operator marked as copied from [source]'s data; see
  /// [unreleasedSource].
  OperatorDetail asUnreleased(String source) {
    return OperatorDetail(
      id: id,
      name: name,
      codename: codename,
      rarity: rarity,
      profession: profession,
      branch: branch,
      teams: teams,
      nations: nations,
      groups: groups,
      baTags: baTags,
      thumbnailHue: thumbnailHue,
      releaseOrder: releaseOrder,
      unreleasedSource: source,
      quote: quote,
      tags: tags,
      traits: traits,
      talents: talents,
      potentials: potentials,
      modules: modules,
      archetypeDescription: archetypeDescription,
      eliteCaps: eliteCaps,
      eliteExpCosts: eliteExpCosts,
      eliteUpgradeGoldCosts: eliteUpgradeGoldCosts,
      eliteEvolveGoldCosts: eliteEvolveGoldCosts,
      eliteEvolveCosts: eliteEvolveCosts,
      allSkillLevelUpCosts: allSkillLevelUpCosts,
      stats: stats,
      skills: skills,
      tokens: tokens,
    );
  }

  factory OperatorDetail.fromJson(Map<String, Object?> json) {
    return OperatorDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      codename: json['codename'] as String,
      rarity: _int(json['rarity']),
      profession: json['profession'] as String,
      branch: json['branch'] as String,
      teams: _strings(json['teams']),
      nations: _strings(json['nations']),
      groups: _strings(json['groups']),
      baTags: _strings(json['baTags']),
      thumbnailHue: _int(json['thumbnailHue']),
      releaseOrder: _optionalInt(json['releaseOrder']),
      unreleasedSource: json['unreleasedSource'] as String?,
      quote: json['quote'] as String,
      tags: _strings(json['tags']),
      traits:
          _list(json['traits'], (value) => OperatorTrait.fromJson(_map(value))),
      talents: _list(
        json['talents'],
        (value) => OperatorTalent.fromJson(_map(value)),
      ),
      potentials: _list(
        json['potentials'],
        (value) => OperatorPotential.fromJson(_map(value)),
      ),
      modules: _list(
        json['modules'],
        (value) => OperatorModule.fromJson(_map(value)),
      ),
      archetypeDescription: json['archetypeDescription'] as String,
      eliteCaps: _ints(json['eliteCaps']),
      eliteExpCosts: _intMatrix(json['eliteExpCosts']),
      eliteUpgradeGoldCosts: _intMatrix(json['eliteUpgradeGoldCosts']),
      eliteEvolveGoldCosts: _ints(json['eliteEvolveGoldCosts']),
      eliteEvolveCosts: _list(
        json['eliteEvolveCosts'],
        (value) => _list(value, (entry) => OperatorCost.fromJson(_map(entry))),
      ),
      allSkillLevelUpCosts: _list(
        json['allSkillLevelUpCosts'],
        (value) => OperatorUpgradeCostStage.fromJson(_map(value)),
      ),
      stats: _list(
        json['stats'],
        (value) => OperatorStatProgression.fromJson(_map(value)),
      ),
      skills:
          _list(json['skills'], (value) => OperatorSkill.fromJson(_map(value))),
      tokens:
          _list(json['tokens'], (value) => OperatorToken.fromJson(_map(value))),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'codename': codename,
      'rarity': rarity,
      'profession': profession,
      'branch': branch,
      'teams': teams,
      'nations': nations,
      'groups': groups,
      'baTags': baTags,
      'thumbnailHue': thumbnailHue,
      'releaseOrder': releaseOrder,
      if (unreleasedSource != null) 'unreleasedSource': unreleasedSource,
      'quote': quote,
      'tags': tags,
      'traits': traits.map((entry) => entry.toJson()).toList(),
      'talents': talents.map((entry) => entry.toJson()).toList(),
      'potentials': potentials.map((entry) => entry.toJson()).toList(),
      'modules': modules.map((entry) => entry.toJson()).toList(),
      'archetypeDescription': archetypeDescription,
      'eliteCaps': eliteCaps,
      'eliteExpCosts': eliteExpCosts,
      'eliteUpgradeGoldCosts': eliteUpgradeGoldCosts,
      'eliteEvolveGoldCosts': eliteEvolveGoldCosts,
      'eliteEvolveCosts': eliteEvolveCosts
          .map((costs) => costs.map((entry) => entry.toJson()).toList())
          .toList(),
      'allSkillLevelUpCosts':
          allSkillLevelUpCosts.map((entry) => entry.toJson()).toList(),
      'stats': stats.map((entry) => entry.toJson()).toList(),
      'skills': skills.map((entry) => entry.toJson()).toList(),
      'tokens': tokens.map((entry) => entry.toJson()).toList(),
    };
  }
}

/// A summon (an upstream `TOKEN` character) an operator deploys.
class OperatorToken {
  const OperatorToken({required this.detail, this.skillIds = const []});

  /// The summon read like an operator, so the detail panels show it as they
  /// show an operator: its description is [OperatorDetail.archetypeDescription]
  /// (the trait text), its elite level caps, stats, range, traits, talents
  /// and skills are its own. Operator-only data (costs, modules, potentials,
  /// tags, factions, summons) is empty.
  final OperatorDetail detail;

  /// Ids of the summoner's skills that deploy this summon instead of the
  /// default one (upstream `overrideTokenKey`). Empty when no skill names
  /// it: the summon is deployed whichever skill is equipped.
  final List<String> skillIds;

  String get id => detail.id;

  /// Whether the summon is deployed whichever skill is equipped.
  bool get forAllSkills => skillIds.isEmpty;

  factory OperatorToken.fromJson(Map<String, Object?> json) {
    return OperatorToken(
      detail: OperatorDetail.fromJson(_map(json['detail'])),
      skillIds: _strings(json['skillIds']),
    );
  }

  Map<String, Object?> toJson() {
    return {'skillIds': skillIds, 'detail': detail.toJson()};
  }
}

class OperatorStatPoint {
  const OperatorStatPoint({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.resistance,
    required this.redeployTime,
    required this.dpCost,
    required this.block,
    required this.attackInterval,
    this.hpRecoveryPerSec = 0,
  });

  final int hp;
  final int attack;
  final int defense;
  final int resistance;
  final int redeployTime;
  final int dpCost;
  final int block;
  final double attackInterval;
  final double hpRecoveryPerSec;

  factory OperatorStatPoint.fromJson(Map<String, Object?> json) {
    return OperatorStatPoint(
      hp: _int(json['hp']),
      attack: _int(json['attack']),
      defense: _int(json['defense']),
      resistance: _int(json['resistance']),
      redeployTime: _int(json['redeployTime']),
      dpCost: _int(json['dpCost']),
      block: _int(json['block']),
      attackInterval: _double(json['attackInterval']),
      hpRecoveryPerSec: _double(json['hpRecoveryPerSec'] ?? 0),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'hp': hp,
      'attack': attack,
      'defense': defense,
      'resistance': resistance,
      'redeployTime': redeployTime,
      'dpCost': dpCost,
      'block': block,
      'attackInterval': attackInterval,
      'hpRecoveryPerSec': hpRecoveryPerSec,
    };
  }
}

class OperatorStatProgression {
  const OperatorStatProgression({
    required this.level,
    required this.min,
    required this.max,
    this.range,
  });

  final int level;
  final OperatorStatPoint min;
  final OperatorStatPoint max;
  final OperatorRange? range;

  factory OperatorStatProgression.fromJson(Map<String, Object?> json) {
    return OperatorStatProgression(
      level: _int(json['level']),
      min: OperatorStatPoint.fromJson(_map(json['min'])),
      max: OperatorStatPoint.fromJson(_map(json['max'])),
      range: json['range'] == null
          ? null
          : OperatorRange.fromJson(_map(json['range'])),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'level': level,
      'min': min.toJson(),
      'max': max.toJson(),
      'range': range?.toJson(),
    };
  }
}

class OperatorBlackboardEntry {
  const OperatorBlackboardEntry({
    required this.key,
    this.value,
    this.valueStr,
  });

  final String key;
  final double? value;
  final String? valueStr;

  factory OperatorBlackboardEntry.fromJson(Map<String, Object?> json) {
    return OperatorBlackboardEntry(
      key: json['key'] as String,
      value: (json['value'] as num?)?.toDouble(),
      valueStr: json['valueStr'] as String?,
    );
  }

  Map<String, Object?> toJson() =>
      {'key': key, 'value': value, 'valueStr': valueStr};
}

class OperatorCost {
  const OperatorCost({
    required this.id,
    required this.count,
    required this.type,
    this.itemName,
    this.itemRarity,
    this.itemIconId,
    this.itemType,
  });

  final String id;
  final double count;
  final String type;
  final String? itemName;
  final String? itemRarity;
  final String? itemIconId;
  final String? itemType;

  factory OperatorCost.fromJson(Map<String, Object?> json) {
    return OperatorCost(
      id: json['id'] as String,
      count: _double(json['count']),
      type: json['type'] as String,
      itemName: json['itemName'] as String?,
      itemRarity: json['itemRarity'] as String?,
      itemIconId: json['itemIconId'] as String?,
      itemType: json['itemType'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'count': count,
      'type': type,
      'itemName': itemName,
      'itemRarity': itemRarity,
      'itemIconId': itemIconId,
      'itemType': itemType,
    };
  }
}

class OperatorUpgradeCostStage {
  const OperatorUpgradeCostStage({
    required this.level,
    this.costs = const [],
  });

  final int level;
  final List<OperatorCost> costs;

  factory OperatorUpgradeCostStage.fromJson(Map<String, Object?> json) {
    return OperatorUpgradeCostStage(
      level: _int(json['level']),
      costs:
          _list(json['costs'], (value) => OperatorCost.fromJson(_map(value))),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'level': level,
      'costs': costs.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorSkillLevel {
  const OperatorSkillLevel({
    required this.level,
    required this.spCost,
    required this.initialSp,
    required this.duration,
    required this.description,
    this.blackboard = const [],
    this.range,
  });

  final int level;
  final int spCost;
  final int initialSp;
  final int duration;
  final String description;
  final List<OperatorBlackboardEntry> blackboard;
  final OperatorRange? range;

  factory OperatorSkillLevel.fromJson(Map<String, Object?> json) {
    return OperatorSkillLevel(
      level: _int(json['level']),
      spCost: _int(json['spCost']),
      initialSp: _int(json['initialSp']),
      duration: _int(json['duration']),
      description: json['description'] as String,
      blackboard: _list(
        json['blackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
      range: json['range'] == null
          ? null
          : OperatorRange.fromJson(_map(json['range'])),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'level': level,
      'spCost': spCost,
      'initialSp': initialSp,
      'duration': duration,
      'description': description,
      'blackboard': blackboard.map((entry) => entry.toJson()).toList(),
      'range': range?.toJson(),
    };
  }
}

class OperatorSkill {
  const OperatorSkill({
    required this.id,
    this.iconId,
    required this.name,
    required this.recoveryType,
    required this.activationType,
    required this.description,
    this.unlockElite = 0,
    this.unlockLevel = 0,
    this.upgradeCosts = const [],
    this.levels = const [],
  });

  final String id;
  final String? iconId;
  final String name;
  final String recoveryType;
  final String activationType;
  final String description;
  final int unlockElite;
  final int unlockLevel;
  final List<OperatorUpgradeCostStage> upgradeCosts;
  final List<OperatorSkillLevel> levels;

  factory OperatorSkill.fromJson(Map<String, Object?> json) {
    return OperatorSkill(
      id: json['id'] as String,
      iconId: json['iconId'] as String?,
      name: json['name'] as String,
      recoveryType: json['recoveryType'] as String,
      activationType: json['activationType'] as String,
      description: json['description'] as String,
      unlockElite: _int(json['unlockElite'] ?? 0),
      unlockLevel: _int(json['unlockLevel'] ?? 0),
      upgradeCosts: _list(
        json['upgradeCosts'],
        (value) => OperatorUpgradeCostStage.fromJson(_map(value)),
      ),
      levels: _list(
        json['levels'],
        (value) => OperatorSkillLevel.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'iconId': iconId,
      'name': name,
      'recoveryType': recoveryType,
      'activationType': activationType,
      'description': description,
      'unlockElite': unlockElite,
      'unlockLevel': unlockLevel,
      'upgradeCosts': upgradeCosts.map((entry) => entry.toJson()).toList(),
      'levels': levels.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorRange {
  const OperatorRange({
    required this.id,
    this.grids = const [],
  });

  final String id;
  final List<OperatorRangeGrid> grids;

  factory OperatorRange.fromJson(Map<String, Object?> json) {
    return OperatorRange(
      id: json['id'] as String,
      grids: _list(
        json['grids'],
        (value) => OperatorRangeGrid.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'grids': grids.map((entry) => entry.toJson()).toList()};
  }
}

class OperatorRangeGrid {
  const OperatorRangeGrid({
    required this.row,
    required this.col,
  });

  final int row;
  final int col;

  factory OperatorRangeGrid.fromJson(Map<String, Object?> json) {
    return OperatorRangeGrid(row: _int(json['row']), col: _int(json['col']));
  }

  Map<String, Object?> toJson() => {'row': row, 'col': col};
}

class OperatorTrait {
  const OperatorTrait({
    required this.groupKey,
    required this.description,
    required this.elite,
    required this.level,
    required this.requiredPotentialRank,
    this.blackboard = const [],
  });

  final String groupKey;
  final String description;
  final int elite;
  final int level;
  final int requiredPotentialRank;
  final List<OperatorBlackboardEntry> blackboard;

  factory OperatorTrait.fromJson(Map<String, Object?> json) {
    return OperatorTrait(
      groupKey: json['groupKey'] as String,
      description: json['description'] as String,
      elite: _int(json['elite']),
      level: _int(json['level']),
      requiredPotentialRank: _int(json['requiredPotentialRank']),
      blackboard: _list(
        json['blackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'groupKey': groupKey,
      'description': description,
      'elite': elite,
      'level': level,
      'requiredPotentialRank': requiredPotentialRank,
      'blackboard': blackboard.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorTalent extends OperatorTrait {
  const OperatorTalent({
    required super.groupKey,
    required this.name,
    required super.description,
    required super.elite,
    required super.level,
    required super.requiredPotentialRank,
    super.blackboard,
  });

  final String name;

  factory OperatorTalent.fromJson(Map<String, Object?> json) {
    return OperatorTalent(
      groupKey: json['groupKey'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      elite: _int(json['elite']),
      level: _int(json['level']),
      requiredPotentialRank: _int(json['requiredPotentialRank']),
      blackboard: _list(
        json['blackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() {
    final json = super.toJson();
    json['name'] = name;
    return json;
  }
}

class OperatorPotential {
  const OperatorPotential({
    required this.rank,
    required this.description,
  });

  final int rank;
  final String description;

  factory OperatorPotential.fromJson(Map<String, Object?> json) {
    return OperatorPotential(
      rank: _int(json['rank']),
      description: json['description'] as String,
    );
  }

  Map<String, Object?> toJson() => {'rank': rank, 'description': description};
}

class OperatorModule {
  const OperatorModule({
    required this.uniEquipId,
    required this.uniEquipName,
    required this.uniEquipIcon,
    required this.uniEquipDesc,
    required this.typeIcon,
    required this.unlockEvolvePhase,
    required this.charId,
    required this.unlockLevel,
    this.missionList = const [],
    this.unlockFavors,
    this.unlockFavorPercents,
    this.itemCost,
    required this.isSpecialEquip,
    this.specialEquipDesc,
    this.battlePhases = const [],
  });

  final String uniEquipId;
  final String uniEquipName;
  final String uniEquipIcon;
  final String uniEquipDesc;
  final String typeIcon;
  final String unlockEvolvePhase;
  final String charId;
  final int unlockLevel;
  final List<String> missionList;
  final Map<String, int>? unlockFavors;
  final Map<String, int>? unlockFavorPercents;
  final Map<String, List<OperatorCost>>? itemCost;
  final bool isSpecialEquip;
  final String? specialEquipDesc;
  final List<OperatorModuleBattlePhase> battlePhases;

  /// Highest stage among [battlePhases]; 0 when the module has none.
  int get maxStage => battlePhases.fold(
        0,
        (max, phase) => phase.equipLevel > max ? phase.equipLevel : max,
      );

  factory OperatorModule.fromJson(Map<String, Object?> json) {
    return OperatorModule(
      uniEquipId: json['uniEquipId'] as String,
      uniEquipName: json['uniEquipName'] as String,
      uniEquipIcon: json['uniEquipIcon'] as String,
      uniEquipDesc: json['uniEquipDesc'] as String,
      typeIcon: json['typeIcon'] as String,
      unlockEvolvePhase: json['unlockEvolvePhase'] as String,
      charId: json['charId'] as String,
      unlockLevel: _int(json['unlockLevel']),
      missionList: _strings(json['missionList']),
      unlockFavors: _intMap(json['unlockFavors']),
      unlockFavorPercents: _intMap(json['unlockFavorPercents']),
      itemCost: _costMap(json['itemCost']),
      isSpecialEquip: json['isSpecialEquip'] as bool,
      specialEquipDesc: json['specialEquipDesc'] as String?,
      battlePhases: _list(
        json['battlePhases'],
        (value) => OperatorModuleBattlePhase.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'uniEquipId': uniEquipId,
      'uniEquipName': uniEquipName,
      'uniEquipIcon': uniEquipIcon,
      'uniEquipDesc': uniEquipDesc,
      'typeIcon': typeIcon,
      'unlockEvolvePhase': unlockEvolvePhase,
      'charId': charId,
      'unlockLevel': unlockLevel,
      'missionList': missionList,
      'unlockFavors': unlockFavors,
      'unlockFavorPercents': unlockFavorPercents,
      'itemCost': itemCost?.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
      'isSpecialEquip': isSpecialEquip,
      'specialEquipDesc': specialEquipDesc,
      'battlePhases': battlePhases.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorModuleBattlePhase {
  const OperatorModuleBattlePhase({
    required this.equipLevel,
    this.parts = const [],
    this.attributeBlackboard = const [],
  });

  final int equipLevel;
  final List<OperatorModuleBattlePart> parts;
  final List<OperatorBlackboardEntry> attributeBlackboard;

  factory OperatorModuleBattlePhase.fromJson(Map<String, Object?> json) {
    return OperatorModuleBattlePhase(
      equipLevel: _int(json['equipLevel']),
      parts: _list(
        json['parts'],
        (value) => OperatorModuleBattlePart.fromJson(_map(value)),
      ),
      attributeBlackboard: _list(
        json['attributeBlackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'equipLevel': equipLevel,
      'parts': parts.map((entry) => entry.toJson()).toList(),
      'attributeBlackboard':
          attributeBlackboard.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorModuleBattlePart {
  const OperatorModuleBattlePart({
    required this.target,
    this.traitCandidates = const [],
    this.talentCandidates = const [],
  });

  final String target;
  final List<OperatorTraitCandidate> traitCandidates;
  final List<OperatorTalentCandidate> talentCandidates;

  factory OperatorModuleBattlePart.fromJson(Map<String, Object?> json) {
    return OperatorModuleBattlePart(
      target: json['target'] as String,
      traitCandidates: _list(
        json['traitCandidates'],
        (value) => OperatorTraitCandidate.fromJson(_map(value)),
      ),
      talentCandidates: _list(
        json['talentCandidates'],
        (value) => OperatorTalentCandidate.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'target': target,
      'traitCandidates':
          traitCandidates.map((entry) => entry.toJson()).toList(),
      'talentCandidates':
          talentCandidates.map((entry) => entry.toJson()).toList(),
    };
  }
}

class OperatorTraitCandidate extends OperatorTrait {
  const OperatorTraitCandidate({
    required super.description,
    required super.elite,
    required super.level,
    required super.requiredPotentialRank,
    super.blackboard,
    this.range,
  }) : super(groupKey: '');

  final OperatorRange? range;

  factory OperatorTraitCandidate.fromJson(Map<String, Object?> json) {
    return OperatorTraitCandidate(
      description: json['description'] as String,
      elite: _int(json['elite']),
      level: _int(json['level']),
      requiredPotentialRank: _int(json['requiredPotentialRank']),
      blackboard: _list(
        json['blackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
      range: json['range'] == null
          ? null
          : OperatorRange.fromJson(_map(json['range'])),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'description': description,
      'elite': elite,
      'level': level,
      'requiredPotentialRank': requiredPotentialRank,
      'blackboard': blackboard.map((entry) => entry.toJson()).toList(),
      'range': range?.toJson(),
    };
  }
}

class OperatorTalentCandidate extends OperatorTraitCandidate {
  const OperatorTalentCandidate({
    this.name,
    required super.description,
    required super.elite,
    required super.level,
    required super.requiredPotentialRank,
    super.blackboard,
    super.range,
  });

  final String? name;

  factory OperatorTalentCandidate.fromJson(Map<String, Object?> json) {
    return OperatorTalentCandidate(
      name: json['name'] as String?,
      description: json['description'] as String,
      elite: _int(json['elite']),
      level: _int(json['level']),
      requiredPotentialRank: _int(json['requiredPotentialRank']),
      blackboard: _list(
        json['blackboard'],
        (value) => OperatorBlackboardEntry.fromJson(_map(value)),
      ),
      range: json['range'] == null
          ? null
          : OperatorRange.fromJson(_map(json['range'])),
    );
  }

  @override
  Map<String, Object?> toJson() {
    final json = super.toJson();
    json['name'] = name;
    return json;
  }
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}

List<String> _strings(Object? value) {
  return (value as List? ?? const []).map((entry) => entry as String).toList();
}

List<int> _ints(Object? value) {
  return (value as List? ?? const []).map(_int).toList();
}

List<List<int>> _intMatrix(Object? value) {
  return (value as List? ?? const []).map(_ints).toList();
}

Map<String, int>? _intMap(Object? value) {
  if (value == null) {
    return null;
  }
  return Map<String, Object?>.from(value as Map).map(
    (key, entry) => MapEntry(key, _int(entry)),
  );
}

Map<String, List<OperatorCost>>? _costMap(Object? value) {
  if (value == null) {
    return null;
  }
  return Map<String, Object?>.from(value as Map).map(
    (key, entry) => MapEntry(
      key,
      _list(entry, (cost) => OperatorCost.fromJson(_map(cost))),
    ),
  );
}

int _int(Object? value) => (value as num).toInt();

int _optionalInt(Object? value) => (value as num?)?.toInt() ?? 0;

double _double(Object? value) => (value as num).toDouble();
