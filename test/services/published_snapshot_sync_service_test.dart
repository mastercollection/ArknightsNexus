import 'dart:convert';
import 'dart:io';

import 'package:arknight_nexus/core/logging/app_logger.dart';
import 'package:arknight_nexus/data_sources/arknights_data_source.dart';
import 'package:arknight_nexus/data_sources/published_data.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/repositories/json_region_cache_repository.dart';
import 'package:arknight_nexus/services/published_snapshot_sync_service.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/snapshot_builder.dart';
import '../support/fake_app_directories.dart';
import '../support/fake_http_client.dart';
import '../support/raw_fixtures.dart';

final _base = Uri.parse('https://pages.test/data/');
final _manifestUri = _base.resolve('manifest.json');
final _snapshotUri = _base.resolve(
  PublishedData.snapshotPath(RegionSnapshot.schemaVersion, RegionCode.kr),
);

void main() {
  late Directory tempRoot;
  late FakeHttpClient upstream;
  late FakeHttpClient pages;
  late JsonRegionCacheRepository cache;
  late _RecordingFallback fallback;
  late _RecordingLogger logger;
  late PublishedSnapshotSyncService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('published-sync-test-');
    upstream = FakeHttpClient();
    await registerRawFixtures(upstream, RegionCode.kr);
    pages = FakeHttpClient();
    cache = JsonRegionCacheRepository(
      FakeAppDirectories(Directory('${tempRoot.path}/app')),
    );
    fallback = _RecordingFallback();
    logger = _RecordingLogger();
    service = PublishedSnapshotSyncService(
      httpClient: pages,
      cache: cache,
      fallback: fallback,
      logger: logger,
      baseUri: _base,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  /// Runs the generator on the raw fixtures and serves its output from
  /// [pages] under [_base].
  Future<PublishedManifest> publish() async {
    final out = Directory('${tempRoot.path}/site/data');
    if (await out.exists()) {
      await out.delete(recursive: true);
    }
    final result = await SnapshotBuilder(
      httpClient: upstream,
      outDir: out,
      log: (_) {},
    ).build(regions: [RegionCode.kr]);
    expect(result.hasFailures, isFalse);
    await for (final entity in out.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = entity.uri.path.substring(out.uri.path.length);
      pages.registerBytes(_base.resolve(relative), await entity.readAsBytes());
      if (relative == PublishedData.manifestFile) {
        pages.registerText(
          _base.resolve(relative),
          await entity.readAsString(),
        );
      }
    }
    return result.manifest;
  }

  /// Syncs the raw fixtures into a separate cache, as the app's raw path does.
  Future<JsonRegionCacheRepository> rawSync() async {
    final rawCache = JsonRegionCacheRepository(
      FakeAppDirectories(Directory('${tempRoot.path}/raw')),
    );
    await DartRegionSyncService(httpClient: upstream, cache: rawCache)
        .syncRegion(RegionCode.kr)
        .drain<void>();
    return rawCache;
  }

  test('the generator output matches what the raw sync path writes', () async {
    final manifest = await publish();
    final rawCache = await rawSync();

    final published = File(
      '${tempRoot.path}/site/data/'
      '${manifest.regions[RegionCode.kr]!.snapshot.path}',
    );
    final publishedJson =
        jsonDecode(await published.readAsString()) as Map<String, Object?>;
    final rawSnapshot = (await rawCache.readSnapshot(RegionCode.kr))!;
    expect(
      _withoutFetchedAt(publishedJson),
      _withoutFetchedAt(_roundTrip(rawSnapshot.toJson())),
    );

    // The app's published path derives the same cache files.
    await service.ensureRegionFresh(RegionCode.kr);
    final snapshot = (await cache.readSnapshot(RegionCode.kr))!;
    expect(
      _withoutFetchedAt(_roundTrip(snapshot.toJson())),
      _withoutFetchedAt(_roundTrip(rawSnapshot.toJson())),
    );
    expect(
      _withoutFetchedAt(
        _roundTrip((await cache.readSummary(RegionCode.kr))!.toJson()),
      ),
      _withoutFetchedAt(
        _roundTrip((await rawCache.readSummary(RegionCode.kr))!.toJson()),
      ),
    );
    expect(
      _withoutFetchedAt((await cache.readStatus(RegionCode.kr))!.toJson()),
      _withoutFetchedAt((await rawCache.readStatus(RegionCode.kr))!.toJson()),
    );
    expect(
      await cache.readTerms(RegionCode.kr),
      await rawCache.readTerms(RegionCode.kr),
    );
  });

  test('the manifest describes the published snapshot', () async {
    final manifest = await publish();
    final entry = manifest.regions[RegionCode.kr]!;

    expect(entry.schemaVersion, RegionSnapshot.schemaVersion);
    expect(entry.versionControl, '68.2.0');
    expect(entry.operatorCount, greaterThan(0));
    expect(
        entry.snapshot.path,
        'v${RegionSnapshot.schemaVersion}/kr/'
        'snapshot.json');
    expect(entry.snapshot.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('ensureRegionFresh installs the published snapshot', () async {
    final manifest = await publish();

    final result = await service.ensureRegionFresh(RegionCode.kr);

    expect(result.status, 'success');
    expect(result.sourceVersion, '68.2.0');
    expect(pages.requestedUris, [_manifestUri, _snapshotUri]);
    expect(fallback.calls, isEmpty);
    final snapshot = (await cache.readSnapshot(RegionCode.kr))!;
    expect(snapshot.operators.first.name, 'Amiya');
    expect(
      snapshot.fetchedAt,
      manifest.regions[RegionCode.kr]!.fetchedAt,
    );
    expect((await cache.readSummary(RegionCode.kr))!.operators, isNotEmpty);
    expect((await cache.readStatus(RegionCode.kr))!.isReady, isTrue);
    expect(await cache.readTerms(RegionCode.kr), isNotEmpty);
  });

  test('ensureRegionFresh does not download when the cache is current',
      () async {
    await publish();
    await service.ensureRegionFresh(RegionCode.kr);
    pages.requestedUris.clear();

    final result = await service.ensureRegionFresh(RegionCode.kr);

    expect(result.status, 'ready');
    expect(pages.requestedUris, [_manifestUri]);
    expect(fallback.calls, isEmpty);
  });

  test('a newer published version replaces the cache', () async {
    await publish();
    await service.ensureRegionFresh(RegionCode.kr);

    upstream.registerText(
      RegionCode.kr.descriptor.dataVersionUri,
      'Stream://torappu-data/v068/rel68.0\n'
      'Change:100034 on 2025/12/16\n'
      'VersionControl:68.3.0\n',
    );
    await publish();
    final result = await service.ensureRegionFresh(RegionCode.kr);

    expect(result.status, 'success');
    expect(
      (await cache.readSnapshot(RegionCode.kr))!.sourceVersion.versionControl,
      '68.3.0',
    );
    expect(fallback.calls, isEmpty);
  });

  test('a SHA-256 mismatch falls back to the raw sync', () async {
    await publish();
    final bytes = await pages.getBytes(_snapshotUri);
    // Same size, one byte changed inside a string value.
    final tampered = utf8.encode(
      utf8.decode(bytes).replaceFirst('Amiya', 'Amiyb'),
    );
    pages.registerBytes(_snapshotUri, tampered);

    final result = await service.ensureRegionFresh(RegionCode.kr);

    expect(result.status, 'fallback');
    expect(fallback.calls, ['ensure kr']);
    expect(await cache.readSnapshot(RegionCode.kr), isNull);
    expect(logger.warnings.single, contains('snapshot download failed'));
  });

  test('a size mismatch falls back to the raw sync', () async {
    await publish();
    final bytes = await pages.getBytes(_snapshotUri);
    pages.registerBytes(_snapshotUri, bytes.sublist(0, bytes.length - 1));

    await service.ensureRegionFresh(RegionCode.kr);

    expect(fallback.calls, ['ensure kr']);
  });

  test('a missing manifest falls back to the raw sync', () async {
    final result = await service.ensureRegionFresh(RegionCode.kr);

    expect(result.status, 'fallback');
    expect(fallback.calls, ['ensure kr']);
    expect(pages.requestedUris, [_manifestUri]);
    expect(logger.warnings.single, contains('manifest unavailable'));
  });

  test('a schema this app does not read falls back to the raw sync', () async {
    await publish();
    final manifest =
        jsonDecode(await pages.getText(_manifestUri)) as Map<String, Object?>;
    final regions = manifest['regions']! as Map<String, Object?>;
    (regions['kr']! as Map<String, Object?>)['schemaVersion'] =
        RegionSnapshot.schemaVersion + 1;
    pages
      ..registerText(_manifestUri, jsonEncode(manifest))
      ..requestedUris.clear();

    await service.ensureRegionFresh(RegionCode.kr);

    expect(fallback.calls, ['ensure kr']);
    expect(pages.requestedUris, [_manifestUri]);
    expect(logger.warnings.single, contains('schema'));
  });

  test('a region that is not published falls back to the raw sync', () async {
    await publish();

    await service.ensureRegionFresh(RegionCode.en);

    expect(fallback.calls, ['ensure en']);
  });

  test('a published copy older than the cache falls back to the raw sync',
      () async {
    await publish();
    // A raw sync of a newer upstream version, after Pages was built.
    upstream.registerText(
      RegionCode.kr.descriptor.dataVersionUri,
      'VersionControl:68.3.0\n',
    );
    await DartRegionSyncService(httpClient: upstream, cache: cache)
        .syncRegion(RegionCode.kr)
        .drain<void>();
    pages.requestedUris.clear();

    await service.ensureRegionFresh(RegionCode.kr);

    expect(fallback.calls, ['ensure kr']);
    expect(pages.requestedUris, [_manifestUri]);
    expect(
      (await cache.readSnapshot(RegionCode.kr))!.sourceVersion.versionControl,
      '68.3.0',
    );
  });

  test('syncRegion reports phases and installs the published snapshot',
      () async {
    await publish();

    final statuses = await service.syncRegion(RegionCode.kr).toList();

    expect(statuses.map((status) => status.phase), [
      SyncPhase.checkingVersion,
      SyncPhase.downloading,
      SyncPhase.normalizing,
      SyncPhase.writingSnapshot,
      SyncPhase.complete,
    ]);
    expect(statuses.last.remoteVersion, '68.2.0');
    expect(fallback.calls, isEmpty);
    expect(await cache.readSnapshot(RegionCode.kr), isNotNull);
    for (final file in ArknightsDataSource.requiredTableFiles) {
      expect(
        pages.requestedUris,
        isNot(contains(RegionCode.kr.descriptor.tableUri(file))),
      );
    }
  });

  test('syncRegion falls back when the snapshot is rejected', () async {
    await publish();
    pages.registerBytes(_snapshotUri, utf8.encode('{}'));

    final statuses = await service.syncRegion(RegionCode.kr).toList();

    expect(fallback.calls, ['sync kr']);
    expect(statuses.last.message, 'fallback');
    expect(await cache.readSnapshot(RegionCode.kr), isNull);
  });

  test('syncRegion falls back when the manifest is missing', () async {
    final statuses = await service.syncRegion(RegionCode.kr).toList();

    expect(fallback.calls, ['sync kr']);
    expect(statuses.last.message, 'fallback');
  });
}

Map<String, Object?> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Map<String, Object?> _withoutFetchedAt(Map<String, Object?> json) =>
    {...json}..remove('fetchedAt');

class _RecordingFallback implements RegionSyncService {
  final calls = <String>[];

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    calls.add('ensure ${region.value}');
    return SyncResult(
      region: region,
      sourceRevision: 'raw',
      sourceVersion: 'raw',
      updatedAt: '',
      operatorCount: 0,
      status: 'fallback',
    );
  }

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    calls.add('sync ${region.value}');
    yield SyncStatus(
      region: region,
      phase: SyncPhase.complete,
      message: 'fallback',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) =>
      throw UnimplementedError();

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) =>
      throw UnimplementedError();

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) =>
      throw UnimplementedError();
}

class _RecordingLogger implements AppLogger {
  final warnings = <String>[];

  @override
  void info(String message) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    warnings.add('$message $error');
  }

  @override
  void severe(String message, [Object? error, StackTrace? stackTrace]) {}
}
