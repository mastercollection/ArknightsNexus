import '../core/http/http_client.dart';
import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import '../repositories/region_cache_repository.dart';
import 'normalizers/building_formula_normalizer.dart';
import 'normalizers/item_normalizer.dart';
import 'normalizers/operator_normalizer.dart';
import 'normalizers/term_normalizer.dart';
import 'region_source.dart';

abstract interface class RegionSyncService {
  Stream<SyncStatus> syncRegion(RegionCode region);

  Future<SyncResult> ensureRegionFresh(RegionCode region);

  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region);

  Future<Map<String, String>> getRegionTerms(RegionCode region);

  Future<Map<String, String>> getRegionStageCodes(RegionCode region);
}

/// Syncs a region from the raw upstream tables, normalizing on the device.
class DartRegionSyncService implements RegionSyncService {
  DartRegionSyncService({
    required NexusHttpClient httpClient,
    required RegionCacheRepository cache,
    ItemNormalizer itemNormalizer = const ItemNormalizer(),
    BuildingFormulaNormalizer buildingFormulaNormalizer =
        const BuildingFormulaNormalizer(),
    TermNormalizer termNormalizer = const TermNormalizer(),
    OperatorNormalizer operatorNormalizer = const OperatorNormalizer(),
  })  : _cache = cache,
        _source = RegionSource(
          httpClient: httpClient,
          itemNormalizer: itemNormalizer,
          buildingFormulaNormalizer: buildingFormulaNormalizer,
          termNormalizer: termNormalizer,
          operatorNormalizer: operatorNormalizer,
        );

  final RegionCacheRepository _cache;
  final RegionSource _source;

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    yield SyncStatus(region: region, phase: SyncPhase.checkingVersion);
    final version = await _source.fetchDataVersion(region);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.downloading,
      remoteVersion: version.versionControl,
    );
    final downloaded = await _source.downloadTables(region);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.normalizing,
      remoteVersion: version.versionControl,
    );
    final normalized =
        await _source.normalizeInBackground(region, version, downloaded);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.writingSnapshot,
      remoteVersion: version.versionControl,
    );
    await writeNormalizedRegion(_cache, normalized);

    yield SyncStatus(
      region: region,
      phase: SyncPhase.complete,
      remoteVersion: version.versionControl,
    );
  }

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    final snapshot = await _cache.readSnapshot(region);
    final remoteVersion = await _source.fetchDataVersion(region);

    if (snapshot != null &&
        snapshot.sourceVersion.versionControl == remoteVersion.versionControl) {
      return readyResult(snapshot);
    }

    final downloaded = await _source.downloadTables(region);
    final normalized =
        await _source.normalizeInBackground(region, remoteVersion, downloaded);
    await writeNormalizedRegion(_cache, normalized);
    return normalized.result;
  }

  @override
  Future<RegionSyncStatus?> getRegionSyncStatus(RegionCode region) {
    return _cache.readStatus(region);
  }

  @override
  Future<Map<String, String>> getRegionTerms(RegionCode region) {
    return _cache.readTerms(region);
  }

  @override
  Future<Map<String, String>> getRegionStageCodes(RegionCode region) async {
    return (await _cache.readSnapshot(region))?.stageCodeMap ?? {};
  }
}

/// The result `ensureRegionFresh` reports when the cached [snapshot] is
/// already current.
SyncResult readyResult(RegionSnapshot snapshot) {
  return SyncResult(
    region: snapshot.region,
    sourceRevision: snapshot.sourceRevision,
    sourceVersion: snapshot.sourceVersion.versionControl,
    updatedAt: snapshot.fetchedAt.toIso8601String(),
    operatorCount: snapshot.operators.length,
    status: 'ready',
  );
}

/// Writes the snapshot and the files derived from it.
Future<void> writeNormalizedRegion(
  RegionCacheRepository cache,
  NormalizedRegion normalized,
) async {
  final region = normalized.snapshot.region;
  await cache.writeSnapshot(normalized.snapshot);
  await cache.writeSummary(normalized.summary);
  await cache.writeStatus(normalized.status);
  await cache.writeTerms(region, normalized.terms);
}
