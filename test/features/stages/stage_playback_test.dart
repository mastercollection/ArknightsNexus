import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/domain/stage.dart';
import 'package:arknight_nexus/features/stages/stage_format.dart';
import 'package:arknight_nexus/features/stages/stage_playback.dart';
import 'package:arknight_nexus/raw_models/enemy_database.dart';
import 'package:arknight_nexus/raw_models/enemy_handbook.dart';
import 'package:arknight_nexus/raw_models/level_data.dart';
import 'package:arknight_nexus/services/normalizers/stage_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StageDetail detail;

  setUpAll(() async {
    const normalizer = StageNormalizer();
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

  test('places the enemies on their paths over time', () {
    final playback = StagePlayback(detail);

    // Nothing has spawned yet; the first slug comes out of the top gate.
    expect(playback.enemiesAt(5), isEmpty);
    final first = playback.enemiesAt(6).single;
    expect((first.row, first.col), (5.0, 10.0));
    expect(first.enemy?.enemyIndex, 'B2');

    // At 0:42 the rioters walk the top lane and the soldiers the bottom
    // one, while the middle gate's slugs are about to reach the goal.
    final at42 = playback.enemiesAt(42);
    List<EnemyOnMap> of(String index) => [
          for (final enemy in at42)
            if (enemy.enemy?.enemyIndex == index) enemy,
        ];
    expect(of('B2'), hasLength(4));
    expect(of('B2').every((enemy) => enemy.col <= 2), isTrue);
    expect(of('17').map((enemy) => enemy.row), [5, 5]);
    expect(of('1').map((enemy) => enemy.row), [1, 1]);
    // 10 s at 1.1 × 0.5 tiles a second from column 10.
    expect(of('17').first.col, closeTo(10 - 5.5, 1e-9));
    // The last enemy leaves 24 s after the last spawn at 118 s.
    expect(playback.duration, 142);

    expect(playback.enemiesAt(playback.duration + 1), isEmpty);
  });

  test('filters by lane and lists the next spawns', () {
    final playback = StagePlayback(detail);
    final order = laneOrder(detail.lanes);
    final top = order.first;

    expect(detail.lanes[top].start, const GridPosition(row: 5, col: 10));
    expect(
      playback.enemiesAt(42, laneIndex: top).map((e) => e.enemy?.enemyIndex),
      ['17', '17'],
    );
    expect(
      playback.spawnsAfter(42).take(2).map((spawn) => spawn.time),
      [50, 50],
    );
    expect(formatStageTime(118), '1:58');
  });
}

Future<Map<String, Object?>> _fixture(String name) async {
  final text = await File('test/support/fixtures/stage/$name').readAsString();
  return Map<String, Object?>.from(jsonDecode(text) as Map);
}
