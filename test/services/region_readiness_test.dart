import 'package:arknight_nexus/core/logging/app_logger.dart';
import 'package:arknight_nexus/data_sources/data_version.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/region_snapshot.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/repositories/region_cache_repository.dart';
import 'package:arknight_nexus/services/region_readiness.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks each region once per session and shares concurrent checks',
      () async {
    final sync = _CountingSync();
    final readiness = RegionReadiness(sync, _SilentLogger());

    await Future.wait([
      readiness.ensure(RegionCode.kr),
      readiness.ensure(RegionCode.kr),
    ]);
    expect(sync.calls[RegionCode.kr], 1);

    // Later getters reuse the session's check; another region gets its own.
    await readiness.ensure(RegionCode.kr);
    await readiness.ensure(RegionCode.en);
    await readiness.ensure(RegionCode.kr);
    expect(sync.calls, {RegionCode.kr: 1, RegionCode.en: 1});
  });

  test('serves a usable cache when the version check fails', () async {
    final sync = _CountingSync()..fail = true;
    final cache = _SnapshotCache({RegionCode.kr});
    final logger = _RecordingLogger();
    final readiness = RegionReadiness(sync, logger, cache: cache);

    await readiness.ensure(RegionCode.kr);
    await readiness.ensure(RegionCode.kr);

    // Offline: logged once, not retried on every getter.
    expect(sync.calls[RegionCode.kr], 1);
    expect(logger.warnings, hasLength(1));
  });

  test('falls back to the cached sync status without a cache repository',
      () async {
    final sync = _CountingSync()
      ..fail = true
      ..readyRegions.add(RegionCode.kr);
    final readiness = RegionReadiness(sync, _SilentLogger());

    await readiness.ensure(RegionCode.kr);
    await expectLater(readiness.ensure(RegionCode.en), throwsStateError);
  });

  test('surfaces a failed check without a cache and recovers later', () async {
    final sync = _CountingSync()..fail = true;
    final readiness = RegionReadiness(
      sync,
      _SilentLogger(),
      cache: _SnapshotCache(const {}),
    );

    await expectLater(readiness.ensure(RegionCode.kr), throwsStateError);

    sync.fail = false;
    await readiness.ensure(RegionCode.kr);
    await readiness.ensure(RegionCode.kr);
    expect(sync.calls[RegionCode.kr], 2);
  });
}

class _RecordingLogger extends _SilentLogger {
  final warnings = <String>[];

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    warnings.add(message);
  }
}

/// Only [readSnapshot] matters to [RegionReadiness].
class _SnapshotCache implements RegionCacheRepository {
  _SnapshotCache(this.cachedRegions);

  final Set<RegionCode> cachedRegions;

  @override
  Future<RegionSnapshot?> readSnapshot(RegionCode region) async {
    if (!cachedRegions.contains(region)) {
      return null;
    }
    return RegionSnapshot(
      schemaVersionValue: RegionSnapshot.schemaVersion,
      region: region,
      sourceRevision: 'test',
      sourceVersion: const DataVersion(versionControl: '68.2.0'),
      fetchedAt: DateTime.utc(2026, 10, 14),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentLogger implements AppLogger {
  @override
  void info(String message) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void severe(String message, [Object? error, StackTrace? stackTrace]) {}
}

class _CountingSync implements RegionSyncService {
  final calls = <RegionCode, int>{};
  final readyRegions = <RegionCode>{};
  bool fail = false;

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    calls.update(region, (count) => count + 1, ifAbsent: () => 1);
    if (fail) {
      throw StateError('offline');
    }
    return SyncResult(
      region: region,
      sourceRevision: 'test',
      sourceVersion: 'test',
      updatedAt: '2026-10-14T00:00:00Z',
      operatorCount: 0,
      status: 'ready',
    );
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) async =>
      readyRegions.contains(region)
          ? RegionSyncStatus(region: region, operatorCount: 1, isReady: true)
          : null;

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async =>
      const {};

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async =>
      const {};

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {}
}
