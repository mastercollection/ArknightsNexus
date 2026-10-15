@Tags(['network'])
library;

import 'dart:io';

import 'package:arknight_nexus/core/http/package_http_client.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_directories.dart';

void main() {
  test(
    'KR sync writes a snapshot that can be re-read',
    () async {
      await _run(() async {
        final tempRoot =
            await Directory.systemTemp.createTemp('nexus-kr-sync-test-');
        addTearDown(() async {
          if (await tempRoot.exists()) {
            await tempRoot.delete(recursive: true);
          }
        });

        final httpClient = PackageHttpClient();
        addTearDown(httpClient.close);
        final cache = JsonRegionCacheRepository(FakeAppDirectories(tempRoot));
        final service =
            DartRegionSyncService(httpClient: httpClient, cache: cache);

        await for (final _ in service.syncRegion(RegionCode.kr)) {}

        // This is the call that fails in the app's operator detail screen.
        final snapshot = await cache.readSnapshot(RegionCode.kr);
        expect(snapshot, isNotNull);
        expect(snapshot!.operators, isNotEmpty);
        // Touch every operator to force full deserialization.
        for (final op in snapshot.operators) {
          expect(op.id, isNotEmpty);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _run(Future<void> Function() body) async {
  await body();
}
