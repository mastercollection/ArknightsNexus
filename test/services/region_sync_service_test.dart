import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';
import '../support/fake_http_client.dart';
import '../support/raw_fixtures.dart';

void main() {
  group('DartRegionSyncService', () {
    late Directory tempRoot;
    late FakeHttpClient http;
    late JsonRegionCacheRepository cache;
    late DartRegionSyncService service;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('region-sync-test-');
      http = FakeHttpClient();
      cache = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
      service = DartRegionSyncService(httpClient: http, cache: cache);
      await registerRawFixtures(http, RegionCode.kr);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('syncs region data and writes cache files', () async {
      final phases = await service
          .syncRegion(RegionCode.kr)
          .map((status) => status.phase)
          .toList();

      expect(phases, [
        SyncPhase.checkingVersion,
        SyncPhase.downloading,
        SyncPhase.normalizing,
        SyncPhase.writingSnapshot,
        SyncPhase.complete,
      ]);
      expect(
        (await cache.readSnapshot(RegionCode.kr))!.operators.first.name,
        'Amiya',
      );
      expect(
        (await cache.readSummary(RegionCode.kr))!.operators.first.id,
        'char_002_amiya',
      );
      expect((await cache.readStatus(RegionCode.kr))!.isReady, isTrue);
      expect(await cache.readTerms(RegionCode.kr), {
        'atk': 'Attack',
        'ba.stun': 'Cannot act',
        'ba.sluggish': 'Movement speed reduced',
      });
      expect(
        http.requestedUris,
        contains(RegionCode.kr.descriptor.dataVersionUri),
      );
      for (final file in ArknightsDataSource.requiredTableFiles) {
        expect(
          http.requestedUris,
          contains(RegionCode.kr.descriptor.tableUri(file)),
        );
      }
    });

    test('a sync replaces the in-memory snapshot readers get', () async {
      await service.syncRegion(RegionCode.kr).drain<void>();
      final first = await cache.readSnapshot(RegionCode.kr);
      expect(identical(first, await cache.readSnapshot(RegionCode.kr)), isTrue);

      http.registerText(
        RegionCode.kr.descriptor.dataVersionUri,
        'Stream://torappu-data/v068/rel68.0\n'
        'Change:100034 on 2025/12/16\n'
        'VersionControl:68.3.0\n',
      );
      await service.ensureRegionFresh(RegionCode.kr);
      final second = await cache.readSnapshot(RegionCode.kr);

      expect(identical(first, second), isFalse);
      expect(second!.sourceVersion.versionControl, '68.3.0');
      expect(first!.sourceVersion.versionControl, '68.2.0');
    });

    test('records table revisions as the source revision like Rust', () async {
      final descriptor = RegionCode.kr.descriptor;
      await service.syncRegion(RegionCode.kr).drain<void>();
      expect(
        (await cache.readStatus(RegionCode.kr))!.sourceRevision,
        descriptor.branch,
      );

      http
        ..registerRevision(
          descriptor.tableUri(ArknightsDataSource.skillTableFile),
          '"skill-etag"',
        )
        ..registerRevision(
          descriptor.tableUri(ArknightsDataSource.characterTableFile),
          '"char-etag"',
        )
        // Game data constants are not part of the Rust revision string.
        ..registerRevision(
          descriptor.tableUri(ArknightsDataSource.gamedataConstFile),
          '"const-etag"',
        );
      await service.syncRegion(RegionCode.kr).drain<void>();

      expect(
        (await cache.readStatus(RegionCode.kr))!.sourceRevision,
        '"char-etag" | "skill-etag"',
      );
    });

    test(
        'ensureRegionFresh returns ready without fetching raw tables when cache is current',
        () async {
      await service.syncRegion(RegionCode.kr).drain<void>();
      http.requestedUris.clear();

      final result = await service.ensureRegionFresh(RegionCode.kr);

      expect(result.status, 'ready');
      expect(http.requestedUris, [RegionCode.kr.descriptor.dataVersionUri]);
    });

    test(
        'ensureRegionFresh re-downloads and re-normalizes when the cached '
        'snapshot schema is outdated even if the data version is unchanged',
        () async {
      await service.syncRegion(RegionCode.kr).drain<void>();

      // Simulate snapshots written by an older normalizer (same remote
      // version, older schema).
      for (final name in [
        'operators.snapshot.json',
        'operators.summary.json',
      ]) {
        final file = File.fromUri(
          tempRoot.uri.resolve('cache/regions/kr/$name'),
        );
        final json =
            jsonDecode(await file.readAsString()) as Map<String, Object?>;
        json['schemaVersion'] = RegionSnapshot.schemaVersion - 1;
        json['operators'] = <Object?>[];
        await file.writeAsString(jsonEncode(json));
      }
      expect(await cache.readSnapshot(RegionCode.kr), isNull);
      expect(await cache.readSummary(RegionCode.kr), isNull);
      http.requestedUris.clear();

      final result = await service.ensureRegionFresh(RegionCode.kr);

      expect(result.status, 'success');
      for (final file in ArknightsDataSource.requiredTableFiles) {
        expect(
          http.requestedUris,
          contains(RegionCode.kr.descriptor.tableUri(file)),
        );
      }
      final snapshot = (await cache.readSnapshot(RegionCode.kr))!;
      expect(snapshot.schemaVersionValue, RegionSnapshot.schemaVersion);
      expect(snapshot.operators.first.profession, 'Caster');
      expect(
        (await cache.readSummary(RegionCode.kr))!.operators.first.baTags,
        ['Stun', 'Slow'],
      );
    });
  });
}
