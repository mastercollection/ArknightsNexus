@Tags(['network'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/http/package_http_client.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/services/published_snapshot_sync_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';
import '../support/noop_app_logger.dart';

/// Installs KR from the published snapshot at [PublishedData.baseUrl]
/// (override with `--dart-define=NEXUS_DATA_BASE_URL=...` to test a local
/// build of `tool/build_snapshots.dart`) and checks it equals what the raw
/// upstream sync produces.
void main() {
  test(
    'the published KR snapshot equals the raw sync result',
    () async {
      final tempRoot =
          await Directory.systemTemp.createTemp('nexus-published-test-');
      addTearDown(() => tempRoot.delete(recursive: true));
      final httpClient = PackageHttpClient();
      addTearDown(httpClient.close);

      final publishedCache = JsonRegionCacheRepository(
        FakeAppDirectories(Directory('${tempRoot.path}/published')),
      );
      final published = PublishedSnapshotSyncService(
        httpClient: httpClient,
        cache: publishedCache,
        fallback: _FailingFallback(),
        logger: NoopAppLogger(),
      );
      final stopwatch = Stopwatch()..start();
      final result = await published.ensureRegionFresh(RegionCode.kr);
      // ignore: avoid_print
      print('published path (${PublishedData.baseUrl}): '
          '${stopwatch.elapsedMilliseconds} ms');
      expect(result.status, 'success');

      final rawCache = JsonRegionCacheRepository(
        FakeAppDirectories(Directory('${tempRoot.path}/raw')),
      );
      stopwatch.reset();
      await DartRegionSyncService(httpClient: httpClient, cache: rawCache)
          .syncRegion(RegionCode.kr)
          .drain<void>();
      // ignore: avoid_print
      print('raw path: ${stopwatch.elapsedMilliseconds} ms');

      final fromPages = (await publishedCache.readSnapshot(RegionCode.kr))!;
      final fromRaw = (await rawCache.readSnapshot(RegionCode.kr))!;
      expect(
        _withoutFetchedAt(fromPages.toJson()),
        _withoutFetchedAt(fromRaw.toJson()),
      );
      expect(
        _withoutFetchedAt(
          (await publishedCache.readSummary(RegionCode.kr))!.toJson(),
        ),
        _withoutFetchedAt(
          (await rawCache.readSummary(RegionCode.kr))!.toJson(),
        ),
      );
      expect(
        await publishedCache.readTerms(RegionCode.kr),
        await rawCache.readTerms(RegionCode.kr),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Map<String, Object?> _withoutFetchedAt(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map<String, Object?>)..remove('fetchedAt');

class _FailingFallback implements RegionSyncService {
  Never _fail() => throw StateError('the published path fell back');

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async => _fail();

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) => _fail();

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) => _fail();

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) => _fail();

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) => _fail();
}
