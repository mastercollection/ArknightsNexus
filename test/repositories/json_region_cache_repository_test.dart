import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/errors/app_failure.dart';
import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/building_formula.dart';
import 'package:arknight_nexus/domain/item.dart';
import 'package:arknight_nexus/domain/operator.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  group('JsonRegionCacheRepository', () {
    late Directory tempRoot;
    late JsonRegionCacheRepository repository;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('nexus-cache-test-');
      repository = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('round trips snapshot, summary, status, and terms', () async {
      final snapshot = _snapshot();
      final summary = _summary();
      const status = RegionSyncStatus(
        region: RegionCode.kr,
        sourceRevision: 'etag',
        sourceVersion: '68.2.0',
        fetchedAt: '2026-05-17T00:00:00.000Z',
        operatorCount: 1,
        isReady: true,
      );
      const terms = {'atk': 'Attack'};

      await repository.writeSnapshot(snapshot);
      await repository.writeSummary(summary);
      await repository.writeStatus(status);
      await repository.writeTerms(RegionCode.kr, terms);

      expect(
        (await repository.readSnapshot(RegionCode.kr))!.operators.single.id,
        'char_002_amiya',
      );
      expect(
        (await repository.readSummary(RegionCode.kr))!.operators.single.name,
        'Amiya',
      );
      expect((await repository.readStatus(RegionCode.kr))!.isReady, isTrue);
      expect(await repository.readTerms(RegionCode.kr), terms);
      expect(
        await File.fromUri(
          tempRoot.uri.resolve('cache/regions/kr/operators.snapshot.json'),
        ).exists(),
        isTrue,
      );
    });

    test('returns null for missing and unsupported schema snapshots', () async {
      expect(await repository.readSnapshot(RegionCode.kr), isNull);

      final regionDir = await Directory.fromUri(
        tempRoot.uri.resolve('cache/regions/kr/'),
      ).create(recursive: true);
      final fixture = await File(
        'test/support/fixtures/snapshots/unsupported_schema_snapshot.json',
      ).readAsString();
      await File.fromUri(regionDir.uri.resolve('operators.snapshot.json'))
          .writeAsString(fixture);

      expect(await repository.readSnapshot(RegionCode.kr), isNull);
    });

    test('throws CacheFailure for malformed JSON', () async {
      final regionDir = await Directory.fromUri(
        tempRoot.uri.resolve('cache/regions/kr/'),
      ).create(recursive: true);
      await File.fromUri(regionDir.uri.resolve('operators.snapshot.json'))
          .writeAsString('{');

      expect(
        () => repository.readSnapshot(RegionCode.kr),
        throwsA(isA<CacheFailure>()),
      );
    });

    test('returns empty terms map when terms cache is missing', () async {
      expect(await repository.readTerms(RegionCode.kr), isEmpty);
    });

    test('decodes the snapshot once and shares it between readers', () async {
      await repository.writeSnapshot(_snapshot());

      final concurrent = await Future.wait([
        repository.readSnapshot(RegionCode.kr),
        repository.readSnapshot(RegionCode.kr),
      ]);
      final later = await repository.readSnapshot(RegionCode.kr);

      expect(concurrent.first, isNotNull);
      expect(identical(concurrent.first, concurrent.last), isTrue);
      expect(identical(concurrent.first, later), isTrue);
    });

    test('a new snapshot replaces the cached one', () async {
      await repository.writeSnapshot(_snapshot());
      final before = await repository.readSnapshot(RegionCode.kr);

      final updated = RegionSnapshot(
        schemaVersionValue: RegionSnapshot.schemaVersion,
        region: RegionCode.kr,
        sourceRevision: 'etag-2',
        sourceVersion: const DataVersion(versionControl: '68.3.0'),
        fetchedAt: DateTime.utc(2026, 6, 1),
      );
      await repository.writeSnapshot(updated);
      final after = await repository.readSnapshot(RegionCode.kr);

      expect(identical(before, after), isFalse);
      expect(after!.sourceVersion.versionControl, '68.3.0');
      expect(after.operators, isEmpty);
      // Other regions are unaffected and still missing.
      expect(await repository.readSnapshot(RegionCode.en), isNull);
    });

    test('caches status and terms until they are rewritten', () async {
      await repository.writeTerms(RegionCode.kr, const {'atk': 'Attack'});
      final terms = await repository.readTerms(RegionCode.kr);
      terms['atk'] = 'changed by a caller';
      expect(await repository.readTerms(RegionCode.kr), {'atk': 'Attack'});

      await repository.writeTerms(RegionCode.kr, const {'def': 'Defense'});
      expect(await repository.readTerms(RegionCode.kr), {'def': 'Defense'});
    });

    test('writes compact JSON and still reads pretty-printed files', () async {
      await repository.writeSnapshot(_snapshot());
      final file = File.fromUri(
        tempRoot.uri.resolve('cache/regions/kr/operators.snapshot.json'),
      );
      final compact = await file.readAsString();
      expect(compact, isNot(contains('\n')));

      final pretty = File.fromUri(
        tempRoot.uri.resolve('cache/regions/en/operators.snapshot.json'),
      );
      await pretty.parent.create(recursive: true);
      final json = (jsonDecode(compact) as Map<String, Object?>)
        ..['region'] = 'en';
      await pretty.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
      final en = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
      expect(
        (await en.readSnapshot(RegionCode.en))!.operators.single.id,
        'char_002_amiya',
      );
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
    stageCodeMap: const {'main_01-07': '1-7'},
    terms: const {'atk': 'Attack'},
    items: const [
      ItemEntry(
        itemId: '30012',
        name: 'Oriron',
        description: 'Material',
        rarity: '3',
        iconId: 'MTL_SL_Orirock',
        sortId: 10,
        usage: 'Upgrade',
        obtainApproach: 'Stage',
        classifyType: 'MATERIAL',
        itemType: 'MATERIAL',
      ),
    ],
    buildingFormulas: const BuildingFormulaBundle(),
    operators: const [
      OperatorDetail(
        id: 'char_002_amiya',
        name: 'Amiya',
        codename: 'Amiya',
        rarity: 5,
        profession: 'CASTER',
        branch: 'Core Caster',
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
        thumbnailHue: 210,
      ),
    ],
  );
}
