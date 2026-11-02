import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/domain/stage.dart';
import 'package:arknight_nexus/raw_models/enemy_database.dart';
import 'package:arknight_nexus/raw_models/enemy_handbook.dart';
import 'package:arknight_nexus/raw_models/level_data.dart';
import 'package:arknight_nexus/raw_models/stage_table.dart';
import 'package:arknight_nexus/raw_models/zone_table.dart';
import 'package:arknight_nexus/services/normalizers/stage_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const normalizer = StageNormalizer();

  test('summarizes stages with their zone', () async {
    final stages = RawStageTable.fromJson(await _fixture('stage_table.json'));
    final zones = RawZoneTable.fromJson(await _fixture('zone_table.json'));

    final summaries = {
      for (final stage in normalizer.summaries(stages, zones))
        stage.stageId: stage,
    };

    final normal = summaries['main_01-07']!;
    expect(normal.code, '1-7');
    expect(normal.name, 'The Tyrant');
    expect(normal.zoneName, 'Episode 1 Evil Time Part 2');
    expect(normal.levelId, 'Obt/Main/level_main_01-07');
    expect(normal.apCost, 6);
    expect(normal.isChallengeMode, isFalse);

    final challenge = summaries['main_01-07#f#']!;
    expect(challenge.isChallengeMode, isTrue);
    expect(challenge.levelId, normal.levelId);
    expect(
      StageSummary.fromJson(normal.toJson()).toJson(),
      normal.toJson(),
    );
  });

  group('stage detail', () {
    late StageDetail detail;

    setUpAll(() async {
      detail = normalizer.detail(
        'main_01-07',
        RawLevelData.fromJson(await _fixture('level_main_01-07.json')),
        RawEnemyDatabase.fromJson(await _fixture('enemy_database.json')),
        RawEnemyHandbookTable.fromJson(
          await _fixture('enemy_handbook_table.json'),
        ),
      );
    });

    test('reads the options and the map bottom row first', () {
      expect(detail.options.characterLimit, 8);
      expect(detail.options.maxLifePoint, 10);
      expect(detail.options.initialCost, 10);
      expect(detail.map.width, 11);
      expect(detail.map.height, 7);
      expect(detail.map.tiles, hasLength(77));

      final route = detail.routes[1];
      expect(route.start, const GridPosition(row: 5, col: 10));
      expect(detail.map.tileAt(route.start).tileKey, 'tile_start');
      expect(detail.map.tileAt(route.end).tileKey, 'tile_end');
      expect(route.waypoints.first, const GridPosition(row: 5, col: 4));
      expect(detail.routes.first.isPlaceholder, isTrue);

      expect(detail.devices.single.characterKey, 'trap_002_emp');
      expect(
        detail.devices.single.position,
        const GridPosition(row: 3, col: 3),
      );
    });

    test('lists the enemies with counts and stage stats', () {
      expect(
        detail.enemies.map((enemy) => enemy.enemyId),
        [
          'enemy_1027_mob',
          'enemy_1028_mocock',
          'enemy_1002_nsabr',
          'enemy_1029_shdsbr',
          'enemy_1007_slime_2',
          'enemy_1030_wteeth',
        ],
      );
      expect(detail.hasVariableSpawns, isFalse);

      final rioter = detail.enemies.first;
      expect(rioter.name, 'Rioter');
      expect(rioter.enemyIndex, '17');
      expect(rioter.count, 4);
      expect(rioter.stats.maxHp, 1700);
      expect(rioter.stats.def, 50);
      expect(rioter.stats.blockCnt, 1);
      expect(rioter.stats.applyWay, 'MELEE');

      // The fixture overrides only this slug's HP in the level.
      final slug = detail.enemies[4];
      expect(slug.count, 23);
      expect(slug.stats.maxHp, 999);
      expect(slug.stats.atk, 185);

      // Not in the archive: named from the database instead.
      final missing = detail.enemies.last;
      expect(missing.enemyIndex, isNull);
      expect(missing.name, isNotEmpty);
    });

    test('round-trips through JSON', () {
      final json = jsonDecode(jsonEncode(detail.toJson()));
      expect(
        StageDetail.fromJson(Map<String, Object?>.from(json as Map)).toJson(),
        detail.toJson(),
      );
    });
  });

  test('applies an enemy level on top of level 0', () async {
    final database =
        RawEnemyDatabase.fromJson(await _fixture('enemy_database.json'));

    final base = database.resolve('enemy_1007_slime_2', 0)!;
    final upgraded = database.resolve('enemy_1007_slime_2', 1)!;

    expect(base.attributes.maxHp.value, 1050);
    expect(upgraded.attributes.maxHp.value, 2850);
    expect(upgraded.attributes.atk.value, 400);
    expect(
      upgraded.attributes.moveSpeed.value,
      base.attributes.moveSpeed.value,
    );
    expect(upgraded.name.value, base.name.value);
    expect(database.resolve('enemy_missing', 0), isNull);
  });

  test('reads the flattened map grid of newer levels', () {
    final map = RawMapData.fromJson({
      'map': {
        'row_size': 2,
        'column_size': 3,
        'matrix_data': [3, 4, 5, 0, 1, 2],
      },
    });

    expect(map.map, [
      [3, 4, 5],
      [0, 1, 2],
    ]);
  });

  test('maps a level id to its file path', () {
    expect(
      levelFilePath('Obt/Main/level_main_01-07'),
      'obt/main/level_main_01-07.json',
    );
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final text = await File('test/support/fixtures/stage/$name').readAsString();
  return Map<String, Object?>.from(jsonDecode(text) as Map);
}
