import 'dart:async';

import '../../data_sources/region_code.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../services/item_service.dart';

/// Port of `useAutoPersist.ts`: debounced persistence keyed on a snapshot
/// string. Callers invoke [notifyChanged] after mutating the tracked state
/// (the Vue version relies on a `watch` of the source).
class PlanAutoPersist<R> {
  PlanAutoPersist({
    required this.snapshot,
    required this.persist,
    this.delay = const Duration(milliseconds: 400),
    this.enabled,
    this.applyPersisted,
    this.onError,
    this.onPersistingChanged,
  });

  /// Returns the current tracked snapshot (`''` when there is nothing).
  final String Function() snapshot;
  final Future<R> Function() persist;
  final Duration delay;
  final bool Function()? enabled;
  final void Function(R result)? applyPersisted;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final void Function(bool persisting)? onPersistingChanged;

  Timer? _timer;
  String _lastPersisted = '';
  bool _pendingAfterCurrent = false;
  bool _persisting = false;
  bool _disposed = false;

  bool get isPersisting => _persisting;

  /// Whether a debounced save is waiting to run.
  bool get hasPendingSave => _timer != null;

  void markPersisted(String value) {
    _lastPersisted = value;
    _pendingAfterCurrent = false;
    _clearTimer();
  }

  /// Equivalent of the Vue `watch(source, ...)` callback.
  void notifyChanged() {
    if (_disposed) {
      return;
    }
    if (enabled != null && !enabled!()) {
      return;
    }
    if (snapshot() == _lastPersisted) {
      // Edited back to the saved state: the queued save would be a no-op.
      _clearTimer();
      return;
    }
    _schedule();
  }

  Future<void> persistNow() async {
    final current = snapshot();
    if (current.isEmpty || current == _lastPersisted) {
      return;
    }
    if (_persisting) {
      _pendingAfterCurrent = true;
      return;
    }

    _setPersisting(true);
    try {
      final result = await persist();
      _lastPersisted = snapshot();
      if (!_disposed && applyPersisted != null) {
        applyPersisted!(result);
        _lastPersisted = snapshot();
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        onError?.call(error, stackTrace);
      }
    } finally {
      if (_pendingAfterCurrent) {
        _pendingAfterCurrent = false;
        if (snapshot() != _lastPersisted && !_disposed) {
          _schedule();
        }
      }
      // Reported after the follow-up is scheduled so listeners can tell
      // "saved" from "another save is queued" through [hasPendingSave].
      _setPersisting(false);
    }
  }

  /// Cancels the debounce timer. When [flush] is set, a pending change is
  /// persisted immediately instead of being dropped.
  void dispose({bool flush = false}) {
    final hadPending = _timer != null;
    _clearTimer();
    _disposed = true;
    if (flush && hadPending) {
      unawaited(persistNow());
    }
  }

  void _schedule() {
    _clearTimer();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(persistNow());
    });
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setPersisting(bool value) {
    _persisting = value;
    if (!_disposed) {
      onPersistingChanged?.call(value);
    }
  }
}

/// Port of `usePlanReferenceData.ts`.
class PlanReferenceData {
  const PlanReferenceData({
    this.items = const [],
    this.itemsById = const {},
    this.formulas = const BuildingFormulaBundle(),
  });

  final List<ItemEntry> items;
  final Map<String, ItemEntry> itemsById;
  final BuildingFormulaBundle formulas;
}

Future<PlanReferenceData> loadPlanReferenceData(
  ItemService itemService,
  RegionCode region,
) async {
  final itemsFuture = itemService.listItems(ItemQuery(region: region));
  final formulasFuture = itemService.listBuildingFormulas(region);
  final items = await itemsFuture;
  final formulas = await formulasFuture;
  return PlanReferenceData(
    items: items,
    itemsById: {for (final item in items) item.itemId: item},
    formulas: formulas,
  );
}
