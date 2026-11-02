/// Normalizes every stage of the full upstream data, downloaded beforehand
/// with `dart run tool/fetch_gamedata.dart`. Skipped by default; run with
/// `flutter test --tags full-data --run-skipped`. Regions that were not
/// downloaded pass without checking anything.
@Tags(['full-data'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/stage.dart';
import 'package:arknight_nexus/raw_models/enemy_database.dart';
import 'package:arknight_nexus/raw_models/enemy_handbook.dart';
import 'package:arknight_nexus/raw_models/level_data.dart';
import 'package:arknight_nexus/raw_models/stage_table.dart';
import 'package:arknight_nexus/raw_models/zone_table.dart';
import 'package:arknight_nexus/services/normalizers/stage_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

const _root = 'build/gamedata';

/// Issues of the upstream repository rather than of the models: reported
/// but not failing. It lacks the level files of some older events and of
/// the Story Mode (`easy_*`) stages.
const _upstreamGaps = {'missing level file'};

void main() {
  for (final region in RegionCode.values) {
    final dir = '$_root/${region.value}/gamedata';
    test(
      '${region.value}: every stage normalizes',
      () async {
        // `--run-skipped` would also run a `skip:`, so check here.
        if (!File('$dir/excel/stage_table.json').existsSync()) {
          // ignore: avoid_print
          print('${region.value}: not downloaded');
          return;
        }
        await _checkRegion(region.value, dir);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

Future<void> _checkRegion(String region, String dir) async {
  const normalizer = StageNormalizer();
  final stageTable =
      RawStageTable.fromJson(_read('$dir/excel/stage_table.json'));
  final zoneTable = RawZoneTable.fromJson(_read('$dir/excel/zone_table.json'));
  final handbook = RawEnemyHandbookTable.fromJson(
    _read('$dir/excel/enemy_handbook_table.json'),
  );
  final database = RawEnemyDatabase.fromJson(
    _read('$dir/levels/enemydata/enemy_database.json'),
  );

  final summaries = normalizer.summaries(stageTable, zoneTable);
  final issues = <String, List<String>>{};
  void issue(String kind, String detail) => (issues[kind] ??= []).add(detail);

  var checked = 0;
  for (final stage in summaries) {
    final levelId = stage.levelId;
    if (levelId == null || levelId.isEmpty) {
      continue;
    }
    if (stage.zoneName == null) {
      issue('unknown zone', '${stage.stageId} (${stage.zoneId})');
    }
    final file = File('$dir/levels/${levelFilePath(levelId)}');
    if (!file.existsSync()) {
      issue('missing level file', '${stage.stageId} ($levelId)');
      continue;
    }

    final RawLevelData level;
    final StageDetail detail;
    try {
      level = RawLevelData.fromJson(_read(file.path));
      detail = normalizer.detail(stage.stageId, level, database, handbook);
    } catch (error) {
      issue('failed to normalize', '${stage.stageId}: $error');
      continue;
    }
    checked++;
    _checkDetail(stage.stageId, level, detail, database, issue);
  }

  final report = StringBuffer(
    '$region: ${summaries.length} stages, '
    '$checked levels normalized\n',
  );
  for (final entry in issues.entries) {
    report.writeln('  ${entry.key}: ${entry.value.length}');
    for (final detail in entry.value.take(10)) {
      report.writeln('    $detail');
    }
  }
  // ignore: avoid_print
  print(report);

  expect(checked, greaterThan(0));
  expect(
    issues.keys.where((kind) => !_upstreamGaps.contains(kind)),
    isEmpty,
    reason: report.toString(),
  );
}

void _checkDetail(
  String stageId,
  RawLevelData level,
  StageDetail detail,
  RawEnemyDatabase database,
  void Function(String kind, String detail) issue,
) {
  final map = detail.map;
  if (level.mapData.map.any((row) => row.length != map.width)) {
    issue('ragged map', stageId);
  }
  if (map.tiles.length != map.width * map.height) {
    issue('tile count', stageId);
  }

  bool inside(GridPosition position) =>
      position.row >= 0 &&
      position.row < map.height &&
      position.col >= 0 &&
      position.col < map.width;

  for (final (index, route) in detail.routes.indexed) {
    if (route.isPlaceholder) {
      continue;
    }
    for (final position in [route.start, route.end, ...route.waypoints]) {
      if (!inside(position)) {
        issue(
          'route off the map',
          '$stageId route $index (${position.row}, ${position.col})',
        );
        break;
      }
    }
  }

  final refs = {for (final ref in level.enemyDbRefs) ref.id};
  for (final ref in level.enemyDbRefs) {
    if (ref.useDb && !database.enemies.containsKey(ref.id)) {
      issue('enemy not in database', '$stageId ${ref.id}');
    }
  }
  for (final wave in level.waves) {
    for (final fragment in wave.fragments) {
      for (final action in fragment.actions) {
        if (action.isSpawn && !refs.contains(action.key)) {
          issue('spawn without enemy ref', '$stageId ${action.key}');
        }
        if (action.isSpawn &&
            (action.routeIndex < 0 ||
                action.routeIndex >= detail.routes.length)) {
          issue('spawn on unknown route', '$stageId ${action.key}');
        }
      }
    }
  }

  for (final enemy in detail.enemies) {
    if (enemy.count > 0 && enemy.stats.maxHp <= 0) {
      issue('spawned enemy without HP', '$stageId ${enemy.enemyId}');
    }
  }
}

Map<String, Object?> _read(String path) {
  return Map<String, Object?>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}
