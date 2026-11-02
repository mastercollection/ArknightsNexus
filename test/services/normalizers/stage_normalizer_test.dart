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
      final enemies = normalizer.enemies(
        RawEnemyDatabase.fromJson(await _fixture('enemy_database.json')),
        RawEnemyHandbookTable.fromJson(
          await _fixture('enemy_handbook_table.json'),
        ),
      );
      detail = normalizer.detail(
        'main_01-07',
        RawLevelData.fromJson(await _fixture('level_main_01-07.json')),
        {for (final enemy in enemies) enemy.enemyId: enemy},
      );
    });

    test('reads the options and the map bottom row first', () {
      expect(detail.options.characterLimit, 8);
      expect(detail.options.maxLifePoint, 10);
      expect(detail.options.initialCost, 10);
      expect(detail.map.width, 11);
      expect(detail.map.height, 7);
      expect(detail.map.tiles, hasLength(77));

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

    test('groups the routes into lanes and paths', () {
      GridPosition at(int row, int col) => GridPosition(row: row, col: col);

      // Three gates on the right, one goal on the left; the middle gate's
      // enemies go round the device above or below it.
      expect(detail.lanes.map((lane) => lane.start), [
        at(5, 10),
        at(1, 10),
        at(3, 10),
      ]);
      expect(detail.lanes.every((lane) => lane.end == at(3, 0)), isTrue);
      expect(detail.lanes.every((lane) => lane.fromGate), isTrue);
      expect(detail.lanes.map((lane) => lane.pathIndexes.length), [1, 1, 2]);
      final enemyCount =
          detail.lanes.fold<int>(0, (sum, lane) => sum + lane.enemyCount);
      expect(enemyCount, 41);
      expect(detail.paths, hasLength(4));

      // Tile by tile through the checkpoints (5,4), (4,4), (4,2), (3,2).
      expect(detail.paths.first.steps.map((step) => step.position), [
        at(5, 10),
        at(5, 9),
        at(5, 8),
        at(5, 7),
        at(5, 6),
        at(5, 5),
        at(5, 4),
        at(4, 4),
        at(4, 3),
        at(4, 2),
        at(3, 2),
        at(3, 1),
        at(3, 0),
      ]);
    });

    test('schedules the spawns as PRTS.Map lists them', () {
      expect(detail.spawns, hasLength(24));
      const times = [6, 12, 18, 19, 32, 35, 50, 50, 53, 56, 65, 65, 71, 71];
      const laterTimes = [75, 76, 86, 87, 94, 94, 99, 107, 108, 116];
      expect(
        detail.spawns.map((spawn) => spawn.time),
        [...times, ...laterTimes],
      );
      expect(detail.lastSpawnTime, 118);
      expect(detail.spawns.first.enemyId, 'enemy_1007_slime_2');
      expect(detail.paths[detail.spawns.first.pathIndex].previewed, isTrue);
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
