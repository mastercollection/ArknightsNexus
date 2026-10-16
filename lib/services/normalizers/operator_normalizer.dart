import 'dart:convert';

import '../../data_sources/region_code.dart';
import '../../domain/operator.dart';
import '../../raw_models/battle_equip.dart';
import '../../raw_models/character.dart';
import '../../raw_models/favor_table.dart';
import '../../raw_models/gamedata_const.dart';
import '../../raw_models/handbook_info.dart';
import '../../raw_models/handbook_team.dart';
import '../../raw_models/item_table.dart';
import '../../raw_models/range_table.dart';
import '../../raw_models/raw_helpers.dart';
import '../../raw_models/skill.dart';
import '../../raw_models/uniequip.dart';

/// Port of the Tauri `normalize_operators` pipeline
/// (`src-tauri/src/normalizers.rs`). Every field mirrors the Rust semantics so
/// the cached snapshot matches what the Tauri app produced.
class OperatorNormalizer {
  const OperatorNormalizer();

  List<OperatorDetail> normalize({
    required RegionCode region,
    required RawCharacterTable characters,
    required RawSkillTable skills,
    required RawGameDataConst constants,
    required RawRangeTable ranges,
    required RawUniequipTable uniequip,
    required RawBattleEquipTable battleEquip,
    required RawFavorTable favor,
    required RawItemTable items,
    required RawHandbookTeamTable handbook,
    required RawHandbookInfoTable handbookInfo,
  }) {
    final releaseOrder = handbookInfo.releaseOrder();
    final context = _Context(
      skills: skills.skills,
      constants: constants,
      ranges: ranges.ranges,
      modulesByChar: uniequip.modulesByChar(),
      battleEquip: battleEquip.equips,
      favor: favor,
      itemsById: items.items,
      subProfNames: uniequip.subProfNames(),
      powerNames: handbook.powerNames(),
      baTermNames: baTermNames(constants),
    );

    final result = <OperatorDetail>[];
    for (final entry in characters.characters.entries) {
      final operator = _operator(
        entry.key,
        entry.value,
        context,
        releaseOrder: releaseOrder[entry.key] ?? 0,
      );
      if (operator != null) {
        result.add(operator);
      }
    }

    // Newest release first; operators missing from the handbook have
    // release order 0 and so come last, ordered by rarity then name.
    result.sort((left, right) {
      final release = right.releaseOrder.compareTo(left.releaseOrder);
      if (release != 0) {
        return release;
      }
      final rarity = right.rarity.compareTo(left.rarity);
      if (rarity != 0) {
        return rarity;
      }
      return compareRustStrings(left.name, right.name);
    });
    return result;
  }

  OperatorDetail? _operator(
    String id,
    RawCharacterEntry character,
    _Context context, {
    required int releaseOrder,
  }) {
    if (character.isNotObtainable ||
        character.profession == 'TOKEN' ||
        character.profession == 'TRAP') {
      return null;
    }

    final constants = context.constants;
    final rarity = character.rarity;
    final tierIndex = rarity > 0 ? rarity - 1 : 0;
    final tierMaxLevels = tierIndex < constants.maxLevel.length
        ? constants.maxLevel[tierIndex]
        : const <int>[];

    final eliteCaps = [
      for (var index = 0; index < character.phases.length; index++)
        index < tierMaxLevels.length
            ? tierMaxLevels[index]
            : character.phases[index].maxLevel,
    ];
    final eliteExpCosts = [
      for (final costs in constants.characterExpMap)
        costs.takeWhile((value) => value >= 0).toList(),
    ];
    final eliteUpgradeGoldCosts = [
      for (final costs in constants.characterUpgradeCostMap)
        costs.takeWhile((value) => value >= 0).toList(),
    ];
    final eliteEvolveGoldCosts = tierIndex < constants.evolveGoldCost.length
        ? constants.evolveGoldCost[tierIndex]
            .where((value) => value >= 0)
            .toList()
        : <int>[];
    final eliteEvolveCosts = [
      for (final phase in character.phases.skip(1))
        _upgradeCosts(phase.evolveCost, context),
    ];
    final allSkillLevelUpCosts = [
      for (var index = 0; index < character.allSkillLvlup.length; index++)
        OperatorUpgradeCostStage(
          level: index + 2,
          costs:
              _upgradeCosts(character.allSkillLvlup[index].lvlUpCost, context),
        ),
    ];

    final stats = <OperatorStatProgression>[];
    for (var index = 0; index < character.phases.length; index++) {
      final phase = character.phases[index];
      if (phase.attributesKeyFrames.isEmpty) {
        continue;
      }
      stats.add(
        OperatorStatProgression(
          level: index + 1,
          min: _keyframe(phase.attributesKeyFrames.first),
          max: _keyframe(phase.attributesKeyFrames.last),
          range: _range(phase.rangeId, context),
        ),
      );
    }

    final traits = <OperatorTrait>[];
    final traitCandidates = character.traitField?.candidates ?? const [];
    for (var index = 0; index < traitCandidates.length; index++) {
      final trait = _traitCandidate(index, traitCandidates[index]);
      if (trait != null) {
        traits.add(trait);
      }
    }

    final talents = <OperatorTalent>[];
    final rawTalents = character.talents ?? const <RawTalent>[];
    for (var groupIndex = 0; groupIndex < rawTalents.length; groupIndex++) {
      for (final candidate in rawTalents[groupIndex].candidates ??
          const <RawTalentCandidate>[]) {
        final talent = _talentCandidate(groupIndex, candidate);
        if (talent != null) {
          talents.add(talent);
        }
      }
    }

    final potentials = <OperatorPotential>[];
    for (var index = 0; index < character.potentialRanks.length; index++) {
      final description = character.potentialRanks[index].description.trim();
      if (description.isNotEmpty) {
        potentials.add(
          OperatorPotential(rank: index + 2, description: description),
        );
      }
    }

    final normalizedSkills = [
      for (final reference in character.skills)
        if (_skill(reference, context) case final skill?) skill,
    ];

    final modules = [
      for (final module in context.modulesByChar[id] ?? const <RawEquipEntry>[])
        _module(module, context),
    ];

    final teams = _resolvePowerNames(character.teamId, context.powerNames);
    final nations = _resolvePowerNames(character.nationId, context.powerNames);
    final groups = _resolvePowerNames(character.groupId, context.powerNames);

    final tags =
        character.tagList.where((value) => value.trim().isNotEmpty).toList();
    final baTags = resolveBaTags(
      context.baTermNames,
      baTagTexts(
        characterTexts: [character.description, character.itemDesc],
        traits: traits,
        talents: talents,
        skills: normalizedSkills,
        modules: modules,
      ),
    );

    return OperatorDetail(
      id: id,
      name: character.name,
      codename: character.appellation.trim().isEmpty
          ? character.name
          : character.appellation,
      rarity: rarity,
      profession: humanizeProfession(character.profession),
      branch: context.subProfNames[character.subProfessionId] ??
          humanizeSlug(character.subProfessionId),
      teams: teams,
      nations: nations,
      groups: groups,
      baTags: baTags,
      thumbnailHue: generateHue(id),
      releaseOrder: releaseOrder,
      quote: character.itemDesc ?? character.description ?? '',
      tags: tags,
      traits: traits,
      talents: talents,
      potentials: potentials,
      modules: modules,
      archetypeDescription: character.description ?? character.itemDesc ?? '',
      eliteCaps: eliteCaps,
      eliteExpCosts: eliteExpCosts,
      eliteUpgradeGoldCosts: eliteUpgradeGoldCosts,
      eliteEvolveGoldCosts: eliteEvolveGoldCosts,
      eliteEvolveCosts: eliteEvolveCosts,
      allSkillLevelUpCosts: allSkillLevelUpCosts,
      stats: stats,
      skills: normalizedSkills,
    );
  }

  OperatorModule _module(RawEquipEntry module, _Context context) {
    final battle = context.battleEquip[module.uniEquipId];
    return OperatorModule(
      uniEquipId: module.uniEquipId,
      uniEquipName: module.uniEquipName,
      uniEquipIcon: module.uniEquipIcon,
      uniEquipDesc: module.uniEquipDesc,
      typeIcon: module.typeIcon,
      unlockEvolvePhase: module.unlockEvolvePhase,
      charId: module.charId,
      unlockLevel: module.unlockLevel,
      missionList: module.missionList,
      unlockFavors: module.unlockFavors,
      unlockFavorPercents: _moduleFavorPercents(module, context.favor),
      itemCost: module.itemCost?.map(
        (key, value) => MapEntry(
          key,
          [for (final cost in value) _cost(cost, context)],
        ),
      ),
      isSpecialEquip: module.isSpecialEquip,
      specialEquipDesc: module.specialEquipDesc,
      battlePhases: battle == null
          ? const []
          : [
              for (final phase in battle.phases)
                OperatorModuleBattlePhase(
                  equipLevel: phase.equipLevel,
                  parts: [
                    for (final part in phase.parts) _battlePart(part, context),
                  ],
                  attributeBlackboard: _blackboard(phase.attributeBlackboard),
                ),
            ],
    );
  }

  Map<String, int>? _moduleFavorPercents(
    RawEquipEntry module,
    RawFavorTable favor,
  ) {
    final unlockFavors = module.unlockFavors;
    if (unlockFavors == null) {
      return null;
    }
    // Stable sort by favor point (ties keep upstream order, like Rust's
    // stable `sort_by_key`).
    final indexed = [
      for (var index = 0; index < favor.favorFrames.length; index++)
        (index, favor.favorFrames[index].data),
    ];
    if (indexed.isEmpty) {
      return null;
    }
    indexed.sort((left, right) {
      final point = left.$2.favorPoint.compareTo(right.$2.favorPoint);
      return point != 0 ? point : left.$1.compareTo(right.$1);
    });

    final percents = <String, int>{};
    for (final entry in unlockFavors.entries) {
      final favorPoint = entry.value;
      if (favorPoint <= 0) {
        continue;
      }
      for (final frame in indexed.reversed) {
        if (frame.$2.favorPoint <= favorPoint) {
          percents[entry.key] = frame.$2.percent < 0 ? 0 : frame.$2.percent;
          break;
        }
      }
    }
    return percents.isEmpty ? null : percents;
  }

  OperatorModuleBattlePart _battlePart(
    RawBattleEquipPart part,
    _Context context,
  ) {
    return OperatorModuleBattlePart(
      target: part.target,
      traitCandidates: [
        for (final candidate in part.traitCandidates)
          if (_moduleTraitCandidate(candidate, context) case final trait?)
            trait,
      ],
      talentCandidates: [
        for (final candidate in part.talentCandidates)
          if (_moduleTalentCandidate(candidate, context) case final talent?)
            talent,
      ],
    );
  }

  OperatorTraitCandidate? _moduleTraitCandidate(
    RawBattleEquipTraitCandidate candidate,
    _Context context,
  ) {
    final description = candidate.additionalDescription?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }
    return OperatorTraitCandidate(
      description: description,
      elite: candidate.unlockCondition.phase,
      level: candidate.unlockCondition.level,
      requiredPotentialRank: _potentialRank(candidate.requiredPotentialRank),
      blackboard: _blackboard(candidate.blackboard),
      range: _range(candidate.rangeId, context),
    );
  }

  OperatorTalentCandidate? _moduleTalentCandidate(
    RawBattleEquipTalentCandidate candidate,
    _Context context,
  ) {
    final description = candidate.upgradeDescription?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }
    final name = candidate.name;
    return OperatorTalentCandidate(
      name: name != null && name.trim().isNotEmpty ? name : null,
      description: description,
      elite: candidate.unlockCondition.phase,
      level: candidate.unlockCondition.level,
      requiredPotentialRank: _potentialRank(candidate.requiredPotentialRank),
      blackboard: _blackboard(candidate.blackboard),
      range: _range(candidate.rangeId, context),
    );
  }

  List<String> _resolvePowerNames(String? id, Map<String, String> powerNames) {
    if (id == null) {
      return const [];
    }
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final name = powerNames[trimmed] ?? humanizeSlug(trimmed);
    return name.trim().isEmpty ? const [] : [name];
  }

  OperatorStatPoint _keyframe(RawKeyFrame keyframe) {
    final data = keyframe.data;
    return OperatorStatPoint(
      hp: data.maxHp.round(),
      attack: data.atk.round(),
      defense: data.def.round(),
      resistance: data.magicResistance.round(),
      redeployTime: data.respawnTime.round(),
      dpCost: data.cost.round(),
      block: data.blockCnt.round(),
      attackInterval: data.baseAttackTime,
      hpRecoveryPerSec: data.hpRecoveryPerSec,
    );
  }

  OperatorSkill? _skill(RawSkillReference reference, _Context context) {
    final skillId = reference.skillId;
    if (skillId == null) {
      return null;
    }
    final skill = context.skills[skillId];
    if (skill == null || skill.levels.isEmpty) {
      return null;
    }
    final firstLevel = skill.levels.first;
    final iconId = skill.iconId;

    return OperatorSkill(
      id: skillId,
      iconId: iconId != null && iconId.trim().isNotEmpty ? iconId : null,
      name: firstLevel.name,
      recoveryType: mapSpRecovery(firstLevel.spData?.spType),
      activationType: mapActivationType(firstLevel.skillType),
      description: firstLevel.description ?? firstLevel.name,
      unlockElite: reference.unlockCond.phase,
      unlockLevel: reference.unlockCond.level,
      upgradeCosts: [
        for (var index = 0; index < reference.levelUpCostCond.length; index++)
          OperatorUpgradeCostStage(
            level: index + 8,
            costs: _upgradeCosts(
              reference.levelUpCostCond[index].levelUpCost,
              context,
            ),
          ),
      ],
      levels: [
        for (var index = 0; index < skill.levels.length; index++)
          _skillLevel(index + 1, skill.levels[index], context),
      ],
    );
  }

  OperatorSkillLevel _skillLevel(
    int level,
    RawSkillLevel skillLevel,
    _Context context,
  ) {
    final spData = skillLevel.spData;
    final duration = skillLevel.duration;
    return OperatorSkillLevel(
      level: level,
      spCost: spData == null ? 0 : _nonNegativeRound(spData.spCost),
      initialSp: spData == null ? 0 : _nonNegativeRound(spData.initSp),
      duration: duration == null ? 0 : _nonNegativeRound(duration),
      description: skillLevel.description ?? skillLevel.name,
      blackboard: _blackboard(skillLevel.blackboard ?? const []),
      range: _range(skillLevel.rangeId, context),
    );
  }

  List<OperatorCost> _upgradeCosts(List<RawCost>? costs, _Context context) {
    return [
      for (final cost in costs ?? const <RawCost>[]) _cost(cost, context),
    ];
  }

  OperatorCost _cost(RawCost cost, _Context context) {
    final item = context.itemsById[cost.id];
    return OperatorCost(
      id: cost.id,
      count: cost.count,
      type: cost.type,
      itemName: item?.name,
      itemRarity: item?.rarity,
      itemIconId: item?.iconId,
      itemType: item?.itemType,
    );
  }

  OperatorRange? _range(String? rangeId, _Context context) {
    if (rangeId == null) {
      return null;
    }
    final trimmed = rangeId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final entry = context.ranges[trimmed];
    if (entry == null) {
      return null;
    }
    return OperatorRange(
      id: entry.id.trim().isEmpty ? trimmed : entry.id,
      grids: [
        for (final grid in entry.grids)
          OperatorRangeGrid(row: grid.row, col: grid.col),
      ],
    );
  }

  OperatorTrait? _traitCandidate(int groupIndex, RawTraitCandidate candidate) {
    final description = candidate.overrideDescripton?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }
    final prefabKey = candidate.prefabKey;
    return OperatorTrait(
      groupKey: prefabKey != null && prefabKey.trim().isNotEmpty
          ? prefabKey
          : 'trait-$groupIndex',
      description: description,
      elite: candidate.unlockCondition.phase,
      level: candidate.unlockCondition.level,
      requiredPotentialRank: _potentialRank(candidate.requiredPotentialRank),
      blackboard: _blackboard(candidate.blackboard),
    );
  }

  OperatorTalent? _talentCandidate(
    int groupIndex,
    RawTalentCandidate candidate,
  ) {
    final name = candidate.name?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    final description = (candidate.description ?? '').trim();
    final prefabKey = candidate.prefabKey;
    return OperatorTalent(
      groupKey: prefabKey != null && prefabKey.trim().isNotEmpty
          ? prefabKey
          : 'talent-$groupIndex',
      name: name,
      description: description.isEmpty ? name : description,
      elite: candidate.unlockCondition.phase,
      level: candidate.unlockCondition.level,
      requiredPotentialRank: _potentialRank(candidate.requiredPotentialRank),
      blackboard: _blackboard(candidate.blackboard),
    );
  }

  List<OperatorBlackboardEntry> _blackboard(List<RawBlackboard> entries) {
    return [
      for (final entry in entries)
        if (entry.key.trim().isNotEmpty)
          OperatorBlackboardEntry(
            key: entry.key.trim(),
            value: entry.value,
            valueStr: entry.valueStr,
          ),
    ];
  }

  /// Rust: `round_number_to_i64(value).max(0) as u8`.
  int _potentialRank(double value) {
    final rounded = value.round();
    return rounded < 0 ? 0 : rounded;
  }

  /// Rust: `value.max(0.0).round() as u32`.
  int _nonNegativeRound(double value) => (value < 0 ? 0.0 : value).round();
}

class _Context {
  const _Context({
    required this.skills,
    required this.constants,
    required this.ranges,
    required this.modulesByChar,
    required this.battleEquip,
    required this.favor,
    required this.itemsById,
    required this.subProfNames,
    required this.powerNames,
    required this.baTermNames,
  });

  final Map<String, RawSkillEntry> skills;
  final RawGameDataConst constants;
  final Map<String, RawRangeEntry> ranges;
  final Map<String, List<RawEquipEntry>> modulesByChar;
  final Map<String, RawBattleEquipEntry> battleEquip;
  final RawFavorTable favor;
  final Map<String, RawItemEntry> itemsById;
  final Map<String, String> subProfNames;
  final Map<String, String> powerNames;
  final Map<String, String> baTermNames;
}

/// Name per `ba.*` term key, from [constants]; blank names are dropped.
Map<String, String> baTermNames(RawGameDataConst constants) {
  final result = <String, String>{};
  for (final term in constants.termDescriptionDict.values) {
    final termId = term.termId.trim();
    final termName = term.termName.trim();
    if (termId.startsWith('ba.') && termName.isNotEmpty) {
      result[termId] = termName;
    }
  }
  return result;
}

/// The texts an operator's BA tags are read from, in tag order: its
/// description and item description, then traits, talents, skills and
/// modules.
///
/// An [OperatorDetail] keeps the description as `archetypeDescription` and
/// the item description as `quote` (each falling back to the other), so
/// `[archetypeDescription, quote]` as [characterTexts] gives the same tags.
Iterable<String> baTagTexts({
  required List<String?> characterTexts,
  required List<OperatorTrait> traits,
  required List<OperatorTalent> talents,
  required List<OperatorSkill> skills,
  required List<OperatorModule> modules,
}) sync* {
  for (final text in characterTexts) {
    if (text != null) {
      yield text;
    }
  }
  for (final trait in traits) {
    yield trait.description;
  }
  for (final talent in talents) {
    yield talent.description;
  }
  for (final skill in skills) {
    yield skill.description;
    for (final level in skill.levels) {
      yield level.description;
    }
  }
  for (final module in modules) {
    yield module.uniEquipDesc;
    if (module.specialEquipDesc case final description?) {
      yield description;
    }
    for (final phase in module.battlePhases) {
      for (final part in phase.parts) {
        for (final candidate in part.traitCandidates) {
          yield candidate.description;
        }
        for (final candidate in part.talentCandidates) {
          yield candidate.description;
        }
      }
    }
  }
}

/// The names in [termNames] of the BA terms [texts] link, in order of first
/// appearance, each name once.
List<String> resolveBaTags(
  Map<String, String> termNames,
  Iterable<String> texts,
) {
  if (termNames.isEmpty) {
    return const [];
  }
  final resolved = <String>[];
  final seen = <String>{};
  for (final text in texts) {
    for (final termId in extractBaTermIds(text)) {
      final termName = termNames[termId];
      if (termName != null && seen.add(termName)) {
        resolved.add(termName);
      }
    }
  }
  return resolved;
}

/// Port of Rust `map_sp_recovery`.
String mapSpRecovery(Object? spType) {
  if (spType is String) {
    return switch (spType) {
      'INCREASE_WITH_TIME' => 'auto_recovery',
      'INCREASE_WHEN_ATTACK' => 'attack_recovery',
      'INCREASE_WHEN_TAKEN_DAMAGE' => 'defense_recovery',
      _ => 'unknown_recovery',
    };
  }
  return switch (spType) {
    1 => 'auto_recovery',
    2 => 'attack_recovery',
    4 => 'defense_recovery',
    _ => 'unknown_recovery',
  };
}

/// Port of Rust `map_activation_type`.
String mapActivationType(String? skillType) {
  return switch (skillType ?? '') {
    'PASSIVE' => 'passive',
    'MANUAL' => 'manual_trigger',
    'AUTO' => 'auto_trigger',
    _ => 'unknown_trigger',
  };
}

/// Port of Rust `humanize_profession`.
String humanizeProfession(String value) {
  return switch (value) {
    'PIONEER' => 'Vanguard',
    'SNIPER' => 'Sniper',
    'MEDIC' => 'Medic',
    'CASTER' => 'Caster',
    'WARRIOR' => 'Guard',
    'TANK' => 'Defender',
    'SUPPORT' => 'Supporter',
    'SPECIAL' => 'Specialist',
    _ => humanizeSlug(value),
  };
}

bool _isAsciiUpper(int rune) => rune >= 0x41 && rune <= 0x5A;

bool _isAsciiLower(int rune) => rune >= 0x61 && rune <= 0x7A;

bool _isSlugSeparator(int rune) => rune == 0x5F || rune == 0x2D || rune == 0x2F;

/// Port of Rust `humanize_slug`.
String humanizeSlug(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Unknown';
  }

  if (!trimmed.runes.any(_isAsciiLower)) {
    final spaced = String.fromCharCodes(
      trimmed.runes.map((rune) => _isSlugSeparator(rune) ? 0x20 : rune),
    );
    return spaced
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      final lower = String.fromCharCodes(
        part.runes.map((rune) => _isAsciiUpper(rune) ? rune + 0x20 : rune),
      );
      final runes = lower.runes.toList();
      return String.fromCharCode(runes.first).toUpperCase() +
          String.fromCharCodes(runes.skip(1));
    }).join(' ');
  }

  final output = StringBuffer();
  var capitalizeNext = true;
  var endsWithSpace = false;

  void write(String text) {
    output.write(text);
    if (text.isNotEmpty) {
      endsWithSpace = text.endsWith(' ');
    }
  }

  for (final rune in trimmed.runes) {
    if (_isSlugSeparator(rune)) {
      write(' ');
      capitalizeNext = true;
      continue;
    }
    if (_isAsciiUpper(rune) && !endsWithSpace && output.isNotEmpty) {
      write(' ');
    }
    final char = String.fromCharCode(rune);
    if (capitalizeNext) {
      write(char.toUpperCase());
      capitalizeNext = false;
    } else if (endsWithSpace) {
      write(char.toUpperCase());
    } else {
      write(char.toLowerCase());
    }
  }
  return output.toString();
}

/// Port of Rust `generate_hue`: wrapping u16 sum of the UTF-8 bytes, mod 360.
int generateHue(String id) {
  var value = 0;
  for (final byte in utf8.encode(id)) {
    value = (value + byte) & 0xFFFF;
  }
  return value % 360;
}

bool _isTermIdChar(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    _isAsciiUpper(unit) ||
    _isAsciiLower(unit) ||
    unit == 0x5F ||
    unit == 0x2E;

/// Port of Rust `extract_ba_term_ids`: finds `@ba.xxx` / `$ba.xxx` term
/// references (ASCII alphanumerics, `_` and `.`).
List<String> extractBaTermIds(String text) {
  final units = text.codeUnits;
  final result = <String>[];
  var cursor = 0;

  while (cursor < units.length) {
    final marker = units[cursor];
    if (marker != 0x40 && marker != 0x24) {
      cursor++;
      continue;
    }

    final start = cursor + 1;
    if (start + 3 >= units.length ||
        units[start] != 0x62 ||
        units[start + 1] != 0x61 ||
        units[start + 2] != 0x2E) {
      cursor++;
      continue;
    }

    var end = start + 3;
    while (end < units.length && _isTermIdChar(units[end])) {
      end++;
    }
    if (end > start + 3) {
      result.add(text.substring(start, end));
    }
    cursor = end;
  }
  return result;
}
