import 'package:arknight_nexus/core/logging/app_logger.dart';
import 'package:arknight_nexus/data_sources/region_code.dart';
import 'package:arknight_nexus/domain/sync_status.dart';
import 'package:arknight_nexus/services/region_readiness.dart';
import 'package:arknight_nexus/services/region_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares concurrent checks and re-checks on later calls', () async {
    final sync = _CountingSync();
    final readiness = RegionReadiness(sync, _SilentLogger());

    await Future.wait([
      readiness.ensure(RegionCode.kr),
      readiness.ensure(RegionCode.kr),
    ]);
    expect(sync.calls[RegionCode.kr], 1);

    // Like Vue's ensureRegionReady, each later getter checks again.
    await readiness.ensure(RegionCode.kr);
    await readiness.ensure(RegionCode.en);
    expect(sync.calls, {RegionCode.kr: 2, RegionCode.en: 1});
  });

  test('surfaces a failed check and recovers on the next call', () async {
    final sync = _CountingSync()..fail = true;
    final readiness = RegionReadiness(sync, _SilentLogger());

    await expectLater(readiness.ensure(RegionCode.kr), throwsStateError);

    sync.fail = false;
    await readiness.ensure(RegionCode.kr);
    expect(sync.calls[RegionCode.kr], 2);
  });
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
      null;

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async =>
      const {};

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) async =>
      const {};

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {}
}
