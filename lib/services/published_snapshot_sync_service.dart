import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../core/concurrency/background.dart';
import '../core/errors/app_failure.dart';
import '../core/http/http_client.dart';
import '../core/logging/app_logger.dart';
import '../data_sources/published_data.dart';
import '../data_sources/region_code.dart';
import '../domain/region_snapshot.dart';
import '../domain/sync_status.dart';
import '../repositories/region_cache_repository.dart';
import 'region_source.dart';
import 'region_sync_service.dart';

/// Syncs a region from the pre-normalized snapshot published on GitHub
/// Pages (about 2 MB compressed) instead of the raw upstream tables (about
/// 80 MB plus normalization on the device).
///
/// Falls back to [_fallback], the raw upstream sync, whenever the published
/// copy cannot be used: the manifest or snapshot cannot be fetched, the
/// snapshot fails its size or SHA-256 check or does not decode, the region
/// or this app's [RegionSnapshot.schemaVersion] is not published, or the
/// published copy is older than the cached snapshot (Pages lags upstream by
/// up to the publishing interval, and a raw sync may have been newer).
/// Every fallback is logged with its reason.
///
/// Without a [fallback] (the web build, where the raw tables are too large
/// to download) the published copy is the only source: failures surface as
/// errors and the age check against the cache is skipped, since the cache
/// can only hold an earlier published copy.
class PublishedSnapshotSyncService implements RegionSyncService {
  PublishedSnapshotSyncService({
    required NexusHttpClient httpClient,
    required RegionCacheRepository cache,
    RegionSyncService? fallback,
    required AppLogger logger,
    Uri? baseUri,
  })  : _httpClient = httpClient,
        _cache = cache,
        _fallback = fallback,
        _logger = logger,
        _baseUri = baseUri ?? PublishedData.baseUri;

  final NexusHttpClient _httpClient;
  final RegionCacheRepository _cache;
  final RegionSyncService? _fallback;
  final AppLogger _logger;
  final Uri _baseUri;

  @override
  Future<SyncResult> ensureRegionFresh(RegionCode region) async {
    final cached = await _readCachedSnapshot(region);
    final PublishedRegion published;
    try {
      published = await _fetchPublishedRegion(region);
    } catch (error, stackTrace) {
      return _fallbackFor(region, 'manifest unavailable', error, stackTrace)
          .ensureRegionFresh(region);
    }

    if (cached != null &&
        cached.sourceVersion.versionControl == published.versionControl) {
      return readyResult(cached);
    }
    final fallback = _fallback;
    if (fallback != null && _isOlderThanCache(published, cached)) {
      _logFallback(region, 'published snapshot is older than the cache');
      return fallback.ensureRegionFresh(region);
    }

    final NormalizedRegion normalized;
    try {
      normalized = await _download(region, published);
    } catch (error, stackTrace) {
      return _fallbackFor(region, 'snapshot download failed', error, stackTrace)
          .ensureRegionFresh(region);
    }
    await writeNormalizedRegion(_cache, normalized);
    return normalized.result;
  }

  @override
  Stream<SyncStatus> syncRegion(RegionCode region) async* {
    yield SyncStatus(region: region, phase: SyncPhase.checkingVersion);
    final cached = await _readCachedSnapshot(region);
    final PublishedRegion published;
    try {
      published = await _fetchPublishedRegion(region);
    } catch (error, stackTrace) {
      yield* _fallbackFor(region, 'manifest unavailable', error, stackTrace)
          .syncRegion(region);
      return;
    }
    final fallback = _fallback;
    if (fallback != null &&
        cached != null &&
        cached.sourceVersion.versionControl != published.versionControl &&
        _isOlderThanCache(published, cached)) {
      _logFallback(region, 'published snapshot is older than the cache');
      yield* fallback.syncRegion(region);
      return;
    }

    final remoteVersion = published.versionControl;
    yield SyncStatus(
      region: region,
      phase: SyncPhase.downloading,
      remoteVersion: remoteVersion,
    );
    final Uint8List bytes;
    try {
      bytes = await _httpClient.getBytes(
        PublishedData.fileUri(_baseUri, published.snapshot.path),
      );
    } catch (error, stackTrace) {
      yield* _fallbackFor(region, 'snapshot download failed', error, stackTrace)
          .syncRegion(region);
      return;
    }

    yield SyncStatus(
      region: region,
      phase: SyncPhase.normalizing,
      remoteVersion: remoteVersion,
    );
    final NormalizedRegion normalized;
    try {
      normalized = await _verifyAndDecode(region, published, bytes);
    } catch (error, stackTrace) {
      yield* _fallbackFor(region, 'snapshot rejected', error, stackTrace)
          .syncRegion(region);
      return;
    }

    yield SyncStatus(
      region: region,
      phase: SyncPhase.writingSnapshot,
      remoteVersion: remoteVersion,
    );
    await writeNormalizedRegion(_cache, normalized);
    _logger.info(
      'Synced ${region.value} from the published snapshot $remoteVersion',
    );

    yield SyncStatus(
      region: region,
      phase: SyncPhase.complete,
      remoteVersion: remoteVersion,
    );
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

  /// The cached snapshot, or null when there is none or it cannot be read
  /// (an unreadable cache is replaced like a missing one).
  Future<RegionSnapshot?> _readCachedSnapshot(RegionCode region) async {
    try {
      return await _cache.readSnapshot(region);
    } catch (_) {
      return null;
    }
  }

  /// Version strings are not ordered, so the snapshots' `fetchedAt` decides:
  /// a published copy normalized before the cached one was fetched must not
  /// replace it.
  bool _isOlderThanCache(PublishedRegion published, RegionSnapshot? cached) {
    return cached != null && !published.fetchedAt.isAfter(cached.fetchedAt);
  }

  Future<PublishedRegion> _fetchPublishedRegion(RegionCode region) async {
    final body = await _httpClient.getText(
      PublishedData.manifestUri(_baseUri),
    );
    final manifest = PublishedManifest.fromJson(
      jsonDecode(body) as Map<String, Object?>,
    );
    final published = manifest.regions[region];
    if (published == null) {
      throw MissingCacheFailure('${region.value} is not published');
    }
    if (published.schemaVersion != RegionSnapshot.schemaVersion) {
      throw MissingCacheFailure(
        'Published ${region.value} snapshot has schema '
        '${published.schemaVersion}; this app reads '
        '${RegionSnapshot.schemaVersion}',
      );
    }
    return published;
  }

  Future<NormalizedRegion> _download(
    RegionCode region,
    PublishedRegion published,
  ) async {
    final bytes = await _httpClient.getBytes(
      PublishedData.fileUri(_baseUri, published.snapshot.path),
    );
    final normalized = await _verifyAndDecode(region, published, bytes);
    _logger.info(
      'Synced ${region.value} from the published snapshot '
      '${published.versionControl}',
    );
    return normalized;
  }

  /// The raw upstream sync to continue with after [reason]. Without one, logs
  /// and rethrows [error], so callers show their error state.
  RegionSyncService _fallbackFor(
    RegionCode region,
    String reason,
    Object error,
    StackTrace stackTrace,
  ) {
    final fallback = _fallback;
    if (fallback == null) {
      _logger.warning(
        'Published snapshot unavailable for ${region.value} ($reason)',
        error,
        stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    _logFallback(region, reason, error, stackTrace);
    return fallback;
  }

  void _logFallback(
    RegionCode region,
    String reason, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.warning(
      'Published snapshot not used for ${region.value} ($reason); '
      'syncing from the raw upstream tables',
      error,
      stackTrace,
    );
  }
}

/// Hashes and decodes on a background isolate: the snapshot is tens of
/// megabytes of JSON.
Future<NormalizedRegion> _verifyAndDecode(
  RegionCode region,
  PublishedRegion published,
  Uint8List bytes,
) {
  final expected = published.snapshot;
  final versionControl = published.versionControl;
  return runInBackground(
    () => verifyPublishedSnapshot(
      region: region,
      expected: expected,
      versionControl: versionControl,
      bytes: bytes,
    ),
  );
}

/// Checks [bytes] against the manifest entry and decodes it into the same
/// cache files a raw sync writes.
NormalizedRegion verifyPublishedSnapshot({
  required RegionCode region,
  required PublishedFile expected,
  required String versionControl,
  required Uint8List bytes,
}) {
  if (bytes.length != expected.bytes) {
    throw ValidationFailure(
      'Published snapshot is ${bytes.length} bytes; '
      'the manifest says ${expected.bytes}',
    );
  }
  final actual = crypto.sha256.convert(bytes).toString();
  if (actual != expected.sha256) {
    throw ValidationFailure(
      'Published snapshot SHA-256 $actual does not match ${expected.sha256}',
    );
  }
  final snapshot = RegionSnapshot.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
  );
  if (snapshot.region != region) {
    throw ValidationFailure(
      'Published snapshot is for ${snapshot.region.value}, '
      'expected ${region.value}',
    );
  }
  if (snapshot.sourceVersion.versionControl != versionControl) {
    throw ValidationFailure(
      'Published snapshot version ${snapshot.sourceVersion.versionControl} '
      'does not match the manifest $versionControl',
    );
  }
  return NormalizedRegion.fromSnapshot(snapshot);
}
