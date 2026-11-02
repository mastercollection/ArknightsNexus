import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/raw_models/enemy_database.dart';
import 'package:arknight_nexus/raw_models/enemy_handbook.dart';
import 'package:arknight_nexus/raw_models/stage_table.dart';
import 'package:arknight_nexus/raw_models/zone_table.dart';
import 'package:arknight_nexus/repositories/memory_region_cache_repository.dart';
import 'package:arknight_nexus/services/normalizers/stage_normalizer.dart';
import 'package:arknight_nexus/services/stage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_client.dart';

void main() {
  late MemoryRegionCacheRepository cache;
  late FakeHttpClient http;
  late CachedStageService service;

  setUp(() async {
    cache = MemoryRegionCacheRepository();
    http = FakeHttpClient();
    service = CachedStageService(cache, http);
    await cache.writeSnapshot(await _snapshot());
  });

  test('lists the snapshot stages', () async {
    final stages = await service.listStages(RegionCode.kr);

    expect(stages.map((stage) => stage.stageId), contains('main_01-07'));
    expect(await service.listStages(RegionCode.en), isEmpty);
  });

  test('fetches a level once and builds its detail', () async {
    final uri = RegionCode.kr.descriptor.levelUri('Obt/Main/level_main_01-07');
    http.registerText(uri, await _fixtureText('level_main_01-07.json'));

    final detail = await service.stageDetail(RegionCode.kr, 'main_01-07');
    final again = await service.stageDetail(RegionCode.kr, 'main_01-07');

    expect(detail.spawns, hasLength(24));
    expect(detail.enemies.first.name, 'Rioter');
    expect(identical(detail, again), isTrue);
    final requests = http.requestedUris.where((requested) => requested == uri);
    expect(requests, hasLength(1));
  });

  test('reports a stage whose level file is missing', () async {
    expect(
      () => service.stageDetail(RegionCode.kr, 'main_01-07'),
      throwsA(isA<MissingLevelFailure>()),
    );
    expect(
      () => service.stageDetail(RegionCode.kr, 'no_such_stage'),
      throwsA(isA<InvalidInputFailure>()),
    );
  });
}

Future<RegionSnapshot> _snapshot() async {
  const normalizer = StageNormalizer();
  return RegionSnapshot(
    schemaVersionValue: RegionSnapshot.schemaVersion,
    region: RegionCode.kr,
    sourceRevision: 'etag',
    sourceVersion: const DataVersion(versionControl: '68.2.0'),
    fetchedAt: DateTime.utc(2026, 11, 3),
    stages: normalizer.summaries(
      RawStageTable.fromJson(await _fixture('stage_table.json')),
      RawZoneTable.fromJson(await _fixture('zone_table.json')),
    ),
    enemies: normalizer.enemies(
      RawEnemyDatabase.fromJson(await _fixture('enemy_database.json')),
      RawEnemyHandbookTable.fromJson(
        await _fixture('enemy_handbook_table.json'),
      ),
    ),
  );
}

Future<String> _fixtureText(String name) =>
    File('test/support/fixtures/stage/$name').readAsString();

Future<Map<String, Object?>> _fixture(String name) async =>
    Map<String, Object?>.from(jsonDecode(await _fixtureText(name)) as Map);
