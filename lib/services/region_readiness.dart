import '../core/logging/app_logger.dart';
import '../data_sources/region_code.dart';
import '../domain/building_formula.dart';
import '../domain/item.dart';
import '../domain/operator.dart';
import '../repositories/region_cache_repository.dart';
import 'item_service.dart';
import 'operator_service.dart';
import 'region_sync_service.dart';

/// Port of `ensureRegionReady` from `src/services/operators.ts`: data getters
/// first run the backend's `ensure_region_fresh` (remote version check,
/// re-sync when it changed).
///
/// The check runs once per region per app session, so switching to another
/// region checks that region the first time; a manual sync refreshes the
/// data on its own. When the check fails (typically offline) but the
/// region already has a usable cached snapshot, the failure is logged and
/// the cache is served. Without a cache the failure is surfaced, and the
/// next call checks again.
///
/// Concurrent callers for the same region share one in-flight check.
class RegionReadiness {
  RegionReadiness(this._sync, this._logger, {RegionCacheRepository? cache})
      : _cache = cache;

  final RegionSyncService _sync;
  final AppLogger _logger;

  /// Decides whether a failed check may fall back to the cache. Without it,
  /// the cached sync status is used instead.
  final RegionCacheRepository? _cache;

  final _checked = <RegionCode>{};
  final _inFlight = <RegionCode, Future<void>>{};

  Future<void> ensure(RegionCode region) {
    if (_checked.contains(region)) {
      return Future<void>.value();
    }
    return _inFlight.putIfAbsent(region, () async {
      try {
        await _sync.ensureRegionFresh(region);
        _checked.add(region);
      } catch (error, stackTrace) {
        if (await _hasUsableCache(region)) {
          _logger.warning(
            'ensureRegionFresh failed for ${region.value}; '
            'serving the cached data',
            error,
            stackTrace,
          );
          _checked.add(region);
          return;
        }
        _logger.warning(
          'ensureRegionFresh failed for ${region.value}',
          error,
          stackTrace,
        );
        rethrow;
      } finally {
        _inFlight.remove(region);
      }
    });
  }

  Future<bool> _hasUsableCache(RegionCode region) async {
    try {
      final cache = _cache;
      if (cache != null) {
        return await cache.readSnapshot(region) != null;
      }
      return (await _sync.getRegionSyncStatus(region))?.isReady ?? false;
    } catch (_) {
      return false;
    }
  }
}

class EnsuringOperatorService implements OperatorService {
  const EnsuringOperatorService(this._inner, this._readiness);

  final OperatorService _inner;
  final RegionReadiness _readiness;

  @override
  Future<List<OperatorSummary>> listOperators(OperatorQuery query) async {
    await _readiness.ensure(query.region);
    return _inner.listOperators(query);
  }

  @override
  Future<OperatorDetail?> getOperatorDetail(
    RegionCode region,
    String operatorId,
  ) async {
    await _readiness.ensure(region);
    return _inner.getOperatorDetail(region, operatorId);
  }
}

class EnsuringItemService implements ItemService {
  const EnsuringItemService(this._inner, this._readiness);

  final ItemService _inner;
  final RegionReadiness _readiness;

  @override
  Future<List<ItemEntry>> listItems(ItemQuery query) async {
    await _readiness.ensure(query.region);
    return _inner.listItems(query);
  }

  @override
  Future<BuildingFormulaBundle> listBuildingFormulas(RegionCode region) async {
    await _readiness.ensure(region);
    return _inner.listBuildingFormulas(region);
  }
}
