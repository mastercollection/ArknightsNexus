import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/raw_models/battle_equip.dart';
import 'package:arknight_nexus/raw_models/building_data.dart';
import 'package:arknight_nexus/raw_models/character.dart';
import 'package:arknight_nexus/raw_models/favor_table.dart';
import 'package:arknight_nexus/raw_models/gamedata_const.dart';
import 'package:arknight_nexus/raw_models/handbook_team.dart';
import 'package:arknight_nexus/raw_models/item_table.dart';
import 'package:arknight_nexus/raw_models/range_table.dart';
import 'package:arknight_nexus/raw_models/skill.dart';
import 'package:arknight_nexus/raw_models/stage_table.dart';
import 'package:arknight_nexus/raw_models/uniequip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('raw model fixtures', () {
    test('decodes character table fixture', () async {
      final table =
          RawCharacterTable.fromJson(await _fixture('character_table.json'));
      final amiya = table.characters['char_002_amiya']!;

      expect(amiya.name, 'Amiya');
      expect(amiya.profession, 'CASTER');
      expect(amiya.phases[1].evolveCost!.single.id, '30012');
      expect(amiya.appellation, 'Amiya-RI');
      expect(amiya.traitField!.candidates, hasLength(2));
      expect(amiya.talents, hasLength(3));
      expect(amiya.potentialRanks, hasLength(3));
      expect(amiya.allSkillLvlup.first.lvlUpCost!.single.id, '3301');
      expect(table.characters['char_token']!.profession, 'TOKEN');
    });

    test('decodes skill, range, module, battle equip, and favor fixtures',
        () async {
      final skills = RawSkillTable.fromJson(await _fixture('skill_table.json'));
      final ranges = RawRangeTable.fromJson(await _fixture('range_table.json'));
      final uniequip =
          RawUniequipTable.fromJson(await _fixture('uniequip_table.json'));
      final battleEquip = RawBattleEquipTable.fromJson(
        await _fixture('battle_equip_table.json'),
      );
      final favor = RawFavorTable.fromJson(await _fixture('favor_table.json'));

      expect(skills.skills['skchr_amiya_1']!.levels.first.spData!.spCost, 20.6);
      expect(ranges.ranges['range_1']!.grids.single.col, 1);
      expect(
        uniequip.subProfDict['caster_core']!.subProfessionName,
        ' Core Caster ',
      );
      expect(uniequip.equipDict['uniequip_002']!.charId, 'char_002_amiya');
      expect(
        battleEquip.equips['uniequip_002']!.phases.single.parts.first.target,
        'TRAIT',
      );
      expect(favor.favorFrames.last.data.favorPoint, 4800);
    });

    test('decodes item, stage, building, constants, and handbook fixtures',
        () async {
      final items = RawItemTable.fromJson(await _fixture('item_table.json'));
      final stages = RawStageTable.fromJson(await _fixture('stage_table.json'));
      final building =
          RawBuildingData.fromJson(await _fixture('building_data.json'));
      final constants =
          RawGameDataConst.fromJson(await _fixture('gamedata_const.json'));
      final handbook = RawHandbookTeamTable.fromJson(
        await _fixture('handbook_team_table.json'),
      );

      expect(items.items['30012']!.stageDropList.single.stageId, 'main_01-07');
      expect(stages.stages['main_01-07']!.code, ' 1-7 ');
      expect(
        building.manufactFormulas['manufact_1']!.costs.single.type,
        'GOLD',
      );
      expect(constants.termDescriptionDict['atk']!.description, 'Attack');
      expect(handbook.powerNames(), {'power_ri': 'Rhodes Island'});
    });
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final content = await File('test/support/fixtures/raw/$name').readAsString();
  return jsonDecode(content) as Map<String, Object?>;
}
