import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/raw_models/battle_equip.dart';
import 'package:arknight_nexus/raw_models/character.dart';
import 'package:arknight_nexus/raw_models/favor_table.dart';
import 'package:arknight_nexus/raw_models/gamedata_const.dart';
import 'package:arknight_nexus/raw_models/handbook_info.dart';
import 'package:arknight_nexus/raw_models/handbook_team.dart';
import 'package:arknight_nexus/raw_models/item_table.dart';
import 'package:arknight_nexus/raw_models/range_table.dart';
import 'package:arknight_nexus/raw_models/skill.dart';
import 'package:arknight_nexus/raw_models/uniequip.dart';
import 'package:arknight_nexus/services/normalizers/operator_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

// Expected values below are what the Tauri `normalize_operators`
// (src-tauri/src/normalizers.rs) produces for the same fixtures.
void main() {
  late List<OperatorDetail> operators;
  late OperatorDetail amiya;

  setUpAll(() async {
    operators = await _normalizeFixtures();
    amiya = operators.firstWhere((operator) => operator.id == 'char_002_amiya');
  });

  OperatorDetail byId(String id) =>
      operators.firstWhere((operator) => operator.id == id);

  group('OperatorNormalizer', () {
    test(
        'skips tokens, traps and unobtainable operators; sorts newest '
        'release first, operators missing from the handbook last', () {
      // Handbook order (oldest first): amiya, hidden (unobtainable), an NPC,
      // bravo. Alpha is not in the handbook.
      expect(
        operators.map((operator) => operator.id),
        ['char_101_bravo', 'char_002_amiya', 'char_100_alpha'],
      );
      expect(
        operators.map((operator) => operator.releaseOrder),
        [4, 1, 0],
      );
    });

    test('orders operators missing from the handbook by rarity desc then name',
        () async {
      final unordered = await _normalizeFixtures(
        handbookInfo: const RawHandbookInfoTable(),
      );
      expect(
        unordered.map((operator) => operator.id),
        ['char_002_amiya', 'char_100_alpha', 'char_101_bravo'],
      );
      expect(
        unordered.map((operator) => operator.releaseOrder),
        everyElement(0),
      );
    });

    test('reads the handbook key order and nothing else', () async {
      final table = RawHandbookInfoTable.fromJson(
        await _fixture('handbook_info_table.json'),
      );
      expect(table.charIds, [
        'char_002_amiya',
        'char_hidden',
        'npc_001_doctor',
        'char_101_bravo',
      ]);
      expect(table.releaseOrder()['char_101_bravo'], 4);
      expect(RawHandbookInfoTable.fromJson(const {}).charIds, isEmpty);
    });

    test('normalizes identity fields like Rust', () {
      expect(amiya.name, 'Amiya');
      expect(amiya.codename, 'Amiya-RI');
      expect(amiya.rarity, 5);
      expect(amiya.profession, 'Caster');
      expect(amiya.branch, 'Core Caster');
      expect(amiya.teams, ['Rhodes Island']);
      expect(amiya.nations, ['Unknown Nation']);
      expect(amiya.groups, isEmpty);
      expect(amiya.thumbnailHue, 199);
      expect(amiya.quote, 'Rhodes Island leader');
      expect(
        amiya.archetypeDescription,
        'Deals <\$ba.stun>stun</> damage @ba.unknown',
      );
      expect(amiya.tags, ['DPS', 'Support']);
      expect(amiya.baTags, ['Stun', 'Slow']);

      final alpha = byId('char_100_alpha');
      expect(alpha.codename, 'Alpha');
      expect(alpha.profession, 'Guard');
      expect(alpha.branch, 'Unknown');
      expect(alpha.quote, 'Quote only');
      // Rust `description.or(item_desc)` keeps an explicit empty string.
      expect(alpha.archetypeDescription, '');
      expect(alpha.baTags, isEmpty);

      final bravo = byId('char_101_bravo');
      expect(bravo.codename, 'Bravo');
      expect(bravo.profession, 'Vanguard');
      expect(bravo.branch, 'Pioneer Unknown');
      expect(bravo.quote, '');
      expect(bravo.archetypeDescription, '');
      expect(bravo.skills, isEmpty);
      expect(bravo.stats, isEmpty);
    });

    test('normalizes traits, talents and potentials', () {
      expect(amiya.traits.map((trait) => trait.toJson()), [
        {
          'groupKey': 'trait-1',
          'description': 'Deals Arts damage',
          'elite': 1,
          'level': 1,
          'requiredPotentialRank': 0,
          'blackboard': [
            {'key': 'atk_scale', 'value': 1.2, 'valueStr': null},
          ],
        },
      ]);
      expect(
        amiya.talents.map(
          (talent) => [
            talent.groupKey,
            talent.name,
            talent.description,
            talent.elite,
            talent.level,
            talent.requiredPotentialRank,
            talent.blackboard.map((entry) => entry.key).toList(),
          ],
        ),
        [
          [
            '1',
            'Spirit Siphon',
            'Recovers SP, applies <\$ba.sluggish>slow</> and <\$ba.stun>stun</>',
            1,
            1,
            0,
            ['sp'],
          ],
          ['1', 'Spirit Siphon', 'Spirit Siphon', 2, 1, 5, <String>[]],
          ['talent-2', 'Echo', 'Echo', 0, 1, 0, <String>[]],
        ],
      );
      expect(amiya.potentials.map((potential) => potential.toJson()), [
        {'rank': 2, 'description': 'Deployment cost -1'},
        {'rank': 4, 'description': 'ATK +25'},
      ]);
    });

    test('normalizes elite caps and progression costs', () {
      expect(amiya.eliteCaps, [50, 70, 80]);
      expect(amiya.eliteExpCosts, [
        [100, 117],
        [120, 172],
        [191],
      ]);
      expect(amiya.eliteUpgradeGoldCosts, [
        [30, 36],
        [48],
        [76],
      ]);
      expect(amiya.eliteEvolveGoldCosts, [20000, 120000]);
      expect(
        amiya.eliteEvolveCosts
            .map((costs) => costs.map((cost) => cost.toJson()).toList()),
        [
          [_oriron(3)],
          <Object?>[],
        ],
      );
      expect(amiya.allSkillLevelUpCosts.map((stage) => stage.toJson()), [
        {
          'level': 2,
          'costs': [
            {
              'id': '3301',
              'count': 5.0,
              'type': 'MATERIAL',
              'itemName': null,
              'itemRarity': null,
              'itemIconId': null,
              'itemType': null,
            },
          ],
        },
        {'level': 3, 'costs': <Object?>[]},
      ]);
    });

    test('resolves item name, rarity, icon and type for costs', () {
      final evolveCost = amiya.eliteEvolveCosts.first.single;
      expect(evolveCost.itemName, 'Oriron');
      expect(evolveCost.itemIconId, 'MTL_SL_Orirock');
      expect(evolveCost.itemRarity, 'TIER_3');
      expect(evolveCost.itemType, 'MATERIAL');

      final masteryCost = amiya.skills.first.upgradeCosts.single.costs.single;
      expect(masteryCost.itemName, 'Oriron');
      expect(masteryCost.itemIconId, 'MTL_SL_Orirock');

      final moduleCosts = amiya.modules[1].itemCost!['1']!;
      expect(moduleCosts.map((cost) => cost.toJson()), [
        _oriron(2),
        {
          'id': 'mod_unlock_token',
          'count': 1.0,
          'type': 'MATERIAL',
          'itemName': 'Module Data Block',
          'itemRarity': '4',
          'itemIconId': 'mod_unlock_token',
          'itemType': '7',
        },
      ]);
    });

    test('uses first and last keyframes with rounding for stats', () {
      expect(amiya.stats.map((stats) => stats.toJson()), [
        {
          'level': 1,
          'min': _stat(hp: 100, atk: 30, def: 20, res: 10),
          'max': _stat(hp: 201, atk: 60, def: 40, res: 10, hpRegen: 0.5),
          'range': {
            'id': 'range_1',
            'grids': [
              {'row': 0, 'col': 1},
            ],
          },
        },
        {
          'level': 2,
          'min': _stat(hp: 300, atk: 90, def: 50, res: 15, dp: 20),
          'max': _stat(hp: 300, atk: 90, def: 50, res: 15, dp: 20),
          'range': null,
        },
      ]);
    });

    test('normalizes skills like Rust', () {
      expect(amiya.skills.map((skill) => skill.id), [
        'skchr_amiya_1',
        'skchr_amiya_2',
      ]);

      final first = amiya.skills[0];
      expect(first.iconId, 'skill_icon');
      expect(first.name, 'Tactical Chant');
      expect(first.recoveryType, 'auto_recovery');
      expect(first.activationType, 'manual_trigger');
      expect(first.description, 'ATK +10% <\$ba.stun>stun</>');
      expect(first.unlockElite, 0);
      expect(first.unlockLevel, 1);
      expect(first.upgradeCosts.map((stage) => stage.toJson()), [
        {
          'level': 8,
          'costs': [_oriron(2)],
        },
      ]);
      expect(first.levels.map((level) => level.toJson()), [
        {
          'level': 1,
          'spCost': 21,
          'initialSp': 0,
          'duration': 20,
          'description': 'ATK +10% <\$ba.stun>stun</>',
          'blackboard': [
            {'key': 'atk', 'value': 0.1, 'valueStr': '10%'},
          ],
          'range': {
            'id': 'range_1',
            'grids': [
              {'row': 0, 'col': 1},
            ],
          },
        },
        {
          'level': 2,
          'spCost': 19,
          'initialSp': 0,
          'duration': 0,
          'description': 'Tactical Chant',
          'blackboard': <Object?>[],
          'range': null,
        },
      ]);

      final second = amiya.skills[1];
      expect(second.iconId, isNull);
      expect(second.recoveryType, 'defense_recovery');
      expect(second.activationType, 'passive');
      expect(second.description, 'Shadow Assault');
      expect(second.unlockElite, 1);
      expect(second.unlockLevel, 1);
      expect(second.upgradeCosts, isEmpty);
    });

    test('normalizes modules like Rust', () {
      expect(amiya.modules.map((module) => module.uniEquipId), [
        'uniequip_001',
        'uniequip_002',
      ]);

      final original = amiya.modules[0];
      expect(original.isSpecialEquip, isTrue);
      expect(original.specialEquipDesc, 'Special <\$ba.stun>stun</>');
      expect(original.itemCost, isNull);
      expect(original.unlockFavors, isNull);
      expect(original.unlockFavorPercents, isNull);
      expect(original.missionList, isEmpty);
      expect(original.battlePhases, isEmpty);

      final module = amiya.modules[1];
      expect(module.isSpecialEquip, isFalse);
      expect(module.unlockFavors, {'1': 4800, '2': 2000, '3': 0});
      expect(module.unlockFavorPercents, {'1': 100, '2': 50});
      expect(module.itemCost!['2'], isEmpty);

      final phase = module.battlePhases.single;
      expect(phase.equipLevel, 1);
      expect(phase.attributeBlackboard.map((entry) => entry.toJson()), [
        {'key': 'atk', 'value': 40.0, 'valueStr': null},
      ]);
      expect(phase.parts.map((part) => part.target), ['TRAIT', 'TALENT']);
      expect(phase.parts[0].talentCandidates, isEmpty);
      expect(phase.parts[0].traitCandidates.map((entry) => entry.toJson()), [
        {
          'description': 'Improved trait <@ba.sluggish>slow</>',
          'elite': 2,
          'level': 1,
          'requiredPotentialRank': 0,
          'blackboard': [
            {'key': 'atk', 'value': 0.05, 'valueStr': null},
          ],
          'range': {
            'id': 'range_1',
            'grids': [
              {'row': 0, 'col': 1},
            ],
          },
        },
      ]);
      expect(phase.parts[1].traitCandidates, isEmpty);
      final talent = phase.parts[1].talentCandidates.single;
      expect(talent.name, isNull);
      expect(talent.description, 'Talent upgraded');
      expect(talent.elite, 2);
      expect(talent.requiredPotentialRank, 2);
      expect(talent.range, isNull);
    });

    test('round trips through JSON unchanged', () {
      final decoded = OperatorDetail.fromJson(
        jsonDecode(jsonEncode(amiya.toJson())) as Map<String, Object?>,
      );
      expect(decoded.toJson(), amiya.toJson());
    });
  });

  group('summons', () {
    late OperatorDetail summoner;

    setUpAll(() async {
      final characters = await _fixture('character_table.json');
      final amiyaJson = characters['char_002_amiya']! as Map<String, Object?>;
      amiyaJson['displayTokenDict'] = {
        'token_drone': true,
        'token_missing': true,
        'token_s2': true,
      };
      final skills = amiyaJson['skills']! as List<Object?>;
      (skills[1]! as Map<String, Object?>)['overrideTokenKey'] = 'token_s2';
      characters['token_drone'] = {
        'name': 'Drone',
        'description': 'Cannot attack; <\$ba.stun>stuns</> on landing',
        'profession': 'TOKEN',
        'subProfessionId': 'notchar1',
        'rarity': 'TIER_1',
        'trait': null,
        'phases': [
          _tokenPhase(maxLevel: 30, hp: 500, rangeId: 'range_1'),
          _tokenPhase(maxLevel: 40, hp: 900),
        ],
        'skills': [
          {
            'skillId': 'skchr_amiya_2',
            'overrideTokenKey': null,
            'levelUpCostCond': {},
            'unlockCond': {'phase': 'PHASE_1', 'level': 1},
          },
          // The same skill again for a later phase, as Ling's dragons list.
          {
            'skillId': 'skchr_amiya_2',
            'levelUpCostCond': {},
            'unlockCond': {'phase': 'PHASE_2', 'level': 1},
          },
        ],
        'talents': [
          {
            'candidates': [
              {
                'unlockCondition': {'phase': 'PHASE_0', 'level': 1},
                'requiredPotentialRank': 0,
                'prefabKey': '0',
                'name': 'Relay',
                'description': 'Counts as the summoner',
                'blackboard': {},
              },
            ],
          },
          {
            'candidates': [
              {
                'unlockCondition': {'phase': 'PHASE_0', 'level': 1},
                'requiredPotentialRank': 0,
                'prefabKey': '-1',
                'name': null,
                'description': null,
                'blackboard': [
                  {'key': 'interval', 'value': 15.0},
                ],
                'isHideTalent': true,
              },
            ],
          },
        ],
        'displayTokenDict': null,
      };
      characters['token_s2'] = {
        'name': 'Spirit',
        'profession': 'TOKEN',
        'rarity': 'TIER_1',
        'phases': [_tokenPhase(maxLevel: 50, hp: 100)],
        'skills': {},
      };
      final normalized = await _normalizeFixtures(
        characters: RawCharacterTable.fromJson(characters),
      );
      expect(
        normalized.map((operator) => operator.id),
        isNot(contains(startsWith('token_'))),
      );
      summoner = normalized.firstWhere((entry) => entry.id == amiya.id);
    });

    test('lists the displayed summons, skipping ids missing from the table',
        () {
      expect(summoner.tokens.map((token) => token.id), [
        'token_drone',
        'token_s2',
      ]);
      expect(amiya.tokens, isEmpty);
      expect(byId('char_101_bravo').tokens, isEmpty);
    });

    test('a summon no skill names is deployed by every skill', () {
      final drone = summoner.tokens.first;
      expect(drone.skillIds, isEmpty);
      expect(drone.forAllSkills, isTrue);
    });

    test('a summon a skill overrides belongs to that skill', () {
      final spirit = summoner.tokens.last;
      expect(spirit.skillIds, ['skchr_amiya_2']);
      expect(spirit.forAllSkills, isFalse);
      expect(spirit.detail.skills, isEmpty);
      expect(spirit.detail.eliteCaps, [50]);
    });

    test('reads a summon like an operator, with its own level caps', () {
      final drone = summoner.tokens.first.detail;
      expect(drone.name, 'Drone');
      expect(drone.rarity, 1);
      expect(drone.profession, 'Token');
      expect(
        drone.archetypeDescription,
        'Cannot attack; <\$ba.stun>stuns</> on landing',
      );
      expect(drone.quote, '');
      expect(drone.traits, isEmpty);
      expect(drone.eliteCaps, [30, 40]);
      expect(drone.stats.map((stat) => stat.max.hp), [500, 900]);
      expect(drone.stats.first.min.hp, 250);
      expect(drone.stats.first.range?.id, 'range_1');
      expect(drone.stats.last.range, isNull);
      expect(drone.talents.map((talent) => talent.name), ['Relay']);
      expect(drone.skills.single.id, 'skchr_amiya_2');
      expect(drone.skills.single.unlockElite, 1);
      expect(drone.skills.single.levels, hasLength(1));
      expect(drone.tokens, isEmpty);
      expect(drone.eliteExpCosts, isEmpty);
      expect(drone.modules, isEmpty);
    });

    test('round trips through JSON unchanged', () {
      final json = jsonDecode(jsonEncode(summoner.toJson()));
      final decoded = OperatorDetail.fromJson(json as Map<String, Object?>);
      expect(decoded.toJson(), summoner.toJson());
      expect(decoded.tokens.last.skillIds, ['skchr_amiya_2']);
      expect(decoded.tokens.first.detail.eliteCaps, [30, 40]);
    });

    test('reads a detail without summons as having none', () {
      final json = amiya.toJson()..remove('tokens');
      expect(OperatorDetail.fromJson(json).tokens, isEmpty);
    });

    test('an unreleased copy keeps its summons', () {
      expect(
        summoner.asUnreleased('cn').tokens.map((token) => token.id),
        ['token_drone', 'token_s2'],
      );
    });
  });

  group('Rust text helpers', () {
    test('humanizeSlug matches humanize_slug', () {
      expect(humanizeSlug('caster_core'), 'Caster Core');
      expect(humanizeSlug('PIONEER'), 'Pioneer');
      expect(humanizeSlug(' TOKEN_TRAP '), 'Token Trap');
      expect(humanizeSlug('physicalDps'), 'Physical Dps');
      expect(humanizeSlug('ABC1_x'), 'A B C1 X');
      expect(humanizeSlug('abc--def'), 'Abc  Def');
      expect(humanizeSlug('a/b'), 'A B');
      expect(humanizeSlug('   '), 'Unknown');
    });

    test('humanizeProfession matches humanize_profession', () {
      expect(humanizeProfession('PIONEER'), 'Vanguard');
      expect(humanizeProfession('WARRIOR'), 'Guard');
      expect(humanizeProfession('TANK'), 'Defender');
      expect(humanizeProfession('SUPPORT'), 'Supporter');
      expect(humanizeProfession('SPECIAL'), 'Specialist');
      expect(humanizeProfession('MEDIC'), 'Medic');
      expect(humanizeProfession('NEW_CLASS'), 'New Class');
    });

    test('generateHue sums UTF-8 bytes with u16 wrapping', () {
      expect(generateHue('char_002_amiya'), 199);
      // 600 * 'z' (122) = 73200 wraps to 7664 → 104 (unwrapped would be 120).
      expect(generateHue('z' * 600), 104);
      // '아' is EC 95 84 in UTF-8 → 517 % 360 (UTF-16 would give 100).
      expect(generateHue('아'), 157);
    });

    test('extractBaTermIds matches extract_ba_term_ids', () {
      expect(
        extractBaTermIds(r'<$ba.stun>x</> @ba.cold_1.x! $ba. @ba'),
        ['ba.stun', 'ba.cold_1.x'],
      );
      expect(extractBaTermIds(r'$ba.'), isEmpty);
      expect(extractBaTermIds('no terms'), isEmpty);
    });

    test('maps sp recovery and activation keys', () {
      expect(mapSpRecovery('INCREASE_WITH_TIME'), 'auto_recovery');
      expect(mapSpRecovery('INCREASE_WHEN_ATTACK'), 'attack_recovery');
      expect(mapSpRecovery('INCREASE_WHEN_TAKEN_DAMAGE'), 'defense_recovery');
      expect(mapSpRecovery('OTHER'), 'unknown_recovery');
      expect(mapSpRecovery(1), 'auto_recovery');
      expect(mapSpRecovery(2), 'attack_recovery');
      expect(mapSpRecovery(4), 'defense_recovery');
      expect(mapSpRecovery(8), 'unknown_recovery');
      expect(mapSpRecovery(null), 'unknown_recovery');
      expect(mapActivationType('PASSIVE'), 'passive');
      expect(mapActivationType('MANUAL'), 'manual_trigger');
      expect(mapActivationType('AUTO'), 'auto_trigger');
      expect(mapActivationType(null), 'unknown_trigger');
    });
  });
}

Map<String, Object?> _oriron(num count) {
  return {
    'id': '30012',
    'count': count.toDouble(),
    'type': 'MATERIAL',
    'itemName': 'Oriron',
    'itemRarity': 'TIER_3',
    'itemIconId': 'MTL_SL_Orirock',
    'itemType': 'MATERIAL',
  };
}

Map<String, Object?> _stat({
  required int hp,
  required int atk,
  required int def,
  required int res,
  int dp = 18,
  double hpRegen = 0,
}) {
  return {
    'hp': hp,
    'attack': atk,
    'defense': def,
    'resistance': res,
    'redeployTime': 70,
    'dpCost': dp,
    'block': 1,
    'attackInterval': 1.6,
    'hpRecoveryPerSec': hpRegen,
  };
}

/// A summon phase whose stats go from half of [hp] to [hp].
Map<String, Object?> _tokenPhase({
  required int maxLevel,
  required int hp,
  String? rangeId,
}) {
  Map<String, Object?> frame(int level, int hp) => {
        'level': level,
        'data': {
          'maxHp': hp,
          'atk': 0,
          'def': 100,
          'magicResistance': 0,
          'cost': 0,
          'blockCnt': 2,
          'baseAttackTime': 1,
          'respawnTime': 15,
          'hpRecoveryPerSec': 0,
        },
      };
  return {
    'characterPrefabKey': 'token',
    'rangeId': rangeId,
    'maxLevel': maxLevel,
    'attributesKeyFrames': [frame(1, hp ~/ 2), frame(maxLevel, hp)],
    'evolveCost': null,
  };
}

Future<List<OperatorDetail>> _normalizeFixtures({
  RawHandbookInfoTable? handbookInfo,
  RawCharacterTable? characters,
}) async {
  return const OperatorNormalizer().normalize(
    region: RegionCode.kr,
    characters: characters ??
        RawCharacterTable.fromJson(await _fixture('character_table.json')),
    skills: RawSkillTable.fromJson(await _fixture('skill_table.json')),
    constants: RawGameDataConst.fromJson(await _fixture('gamedata_const.json')),
    ranges: RawRangeTable.fromJson(await _fixture('range_table.json')),
    uniequip: RawUniequipTable.fromJson(await _fixture('uniequip_table.json')),
    battleEquip: RawBattleEquipTable.fromJson(
      await _fixture('battle_equip_table.json'),
    ),
    favor: RawFavorTable.fromJson(await _fixture('favor_table.json')),
    items: RawItemTable.fromJson(await _fixture('item_table.json')),
    handbook: RawHandbookTeamTable.fromJson(
      await _fixture('handbook_team_table.json'),
    ),
    handbookInfo: handbookInfo ??
        RawHandbookInfoTable.fromJson(
          await _fixture('handbook_info_table.json'),
        ),
  );
}

Future<Map<String, Object?>> _fixture(String name) async {
  final content = await File('test/support/fixtures/raw/$name').readAsString();
  return jsonDecode(content) as Map<String, Object?>;
}
