import 'dart:io';

import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/services/operator_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  group('CachedOperatorService', () {
    late Directory tempRoot;
    late CachedOperatorService service;

    setUp(() async {
      tempRoot =
          await Directory.systemTemp.createTemp('operator-service-test-');
      final cache = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
      await cache.writeSnapshot(_snapshot());
      await cache.writeSummary(_summary());
      service = CachedOperatorService(cache);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('filters summaries by search, rarity, and profession', () async {
      expect(
        await service.listOperators(
          const OperatorQuery(region: RegionCode.kr, search: 'rhodes'),
        ),
        hasLength(1),
      );
      expect(
        await service.listOperators(
          const OperatorQuery(region: RegionCode.kr, rarity: 5),
        ),
        hasLength(1),
      );
      expect(
        await service.listOperators(
          const OperatorQuery(region: RegionCode.kr, profession: 'CASTER'),
        ),
        hasLength(1),
      );
      expect(
        await service.listOperators(
          const OperatorQuery(region: RegionCode.kr, search: 'guard'),
        ),
        isEmpty,
      );
    });

    test('loads operator detail by id', () async {
      expect(
        (await service.getOperatorDetail(RegionCode.kr, 'char_002_amiya'))!
            .name,
        'Amiya',
      );
      expect(await service.getOperatorDetail(RegionCode.kr, 'missing'), isNull);
    });
  });
}

RegionSnapshot _snapshot() {
  return RegionSnapshot(
    schemaVersionValue: RegionSnapshot.schemaVersion,
    region: RegionCode.kr,
    sourceRevision: 'etag',
    sourceVersion: const DataVersion(versionControl: '68.2.0'),
    fetchedAt: DateTime.utc(2026, 5, 17),
    buildingFormulas: const BuildingFormulaBundle(),
    operators: const [
      OperatorDetail(
        id: 'char_002_amiya',
        name: 'Amiya',
        codename: 'Amiya',
        rarity: 5,
        profession: 'CASTER',
        branch: 'Core Caster',
        teams: ['Rhodes Island'],
        nations: ['Rhodes Island'],
        groups: ['Rhodes Island'],
        thumbnailHue: 210,
        quote: 'Leader',
        archetypeDescription: 'Core caster',
      ),
    ],
  );
}

RegionSummarySnapshot _summary() {
  return RegionSummarySnapshot(
    schemaVersionValue: RegionSnapshot.schemaVersion,
    region: RegionCode.kr,
    sourceRevision: 'etag',
    sourceVersion: const DataVersion(versionControl: '68.2.0'),
    fetchedAt: DateTime.utc(2026, 5, 17),
    operators: const [
      OperatorSummary(
        id: 'char_002_amiya',
        name: 'Amiya',
        rarity: 5,
        profession: 'CASTER',
        branch: 'Core Caster',
        teams: ['Rhodes Island'],
        nations: ['Rhodes Island'],
        groups: ['Rhodes Island'],
        thumbnailHue: 210,
      ),
    ],
  );
}
