import '../core/logging/app_logger.dart';
import '../data_sources/region_code.dart';
import '../domain/building_formula.dart';
import '../domain/item.dart';
import '../domain/operator.dart';
import 'item_service.dart';
import 'operator_service.dart';
import 'region_sync_service.dart';

/// Port of `ensureRegionReady` from `src/services/operators.ts`: every data
/// getter first runs the backend's `ensure_region_fresh` (remote version
/// check, re-sync when it changed). Like the Tauri app, a failed check is
/// surfaced to the caller instead of silently serving the cache.
///
/// Concurrent callers for the same region share one in-flight check.
class RegionReadiness {
  RegionReadiness(this._sync, this._logger);

  final RegionSyncService _sync;
  final AppLogger _logger;
  final _inFlight = <RegionCode, Future<void>>{};

  Future<void> ensure(RegionCode region) {
    return _inFlight.putIfAbsent(region, () async {
      try {
        await _sync.ensureRegionFresh(region);
      } catch (error, stackTrace) {
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
