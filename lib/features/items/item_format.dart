import 'package:intl/intl.dart';

import '../../domain/item.dart';

/// Upper bound of the owned-count editor (`items.vue`).
const maxOwnedCount = 9999999;

final _ownedCountFormatter = NumberFormat.decimalPattern();

/// Port of `formatOwnedCount` from `items.vue`; LMD keeps a compact K/M
/// notation.
String formatOwnedCount(num count, [String? itemId]) {
  final normalized = count < 0 ? 0 : count.truncate();
  if (itemId != lmdItemId) {
    return _ownedCountFormatter.format(normalized);
  }
  if (normalized < 1000000) {
    return '${(normalized / 1000).toStringAsFixed(1)}K';
  }
  return '${(normalized / 1000000).toStringAsFixed(1)}M';
}

/// Port of `normalizeOwnedCountInput`: digits only, empty -> `0`, clamped.
String normalizeOwnedCountInput(String value) {
  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) {
    return '0';
  }
  final parsed = BigInt.parse(digitsOnly);
  final clamped =
      parsed > BigInt.from(maxOwnedCount) ? maxOwnedCount : parsed.toInt();
  return '$clamped';
}

/// Clamp used by `setOwnedCountDraftValue`.
int clampOwnedCount(num value) {
  final truncated = value.truncate();
  if (truncated < 0) {
    return 0;
  }
  return truncated > maxOwnedCount ? maxOwnedCount : truncated;
}

/// Hold-to-repeat step from `getHoldStep`.
int ownedCountHoldStep(Duration elapsed) {
  if (elapsed.inMilliseconds >= 3000) {
    return 10;
  }
  if (elapsed.inMilliseconds >= 1500) {
    return 5;
  }
  return 1;
}

/// JavaScript `String(number)` for counts that are usually integral.
String formatJsNumber(num value) {
  if (value == value.truncate()) {
    return '${value.truncate()}';
  }
  return '$value';
}

/// Penguin stage ids may carry a `_perm` suffix that the stage-code map omits.
String penguinStageLabel(String stageId, Map<String, String> stageCodeMap) {
  final normalized =
      stageId.replaceAll(RegExp(r'_perm$', caseSensitive: false), '');
  final direct = stageCodeMap[stageId];
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final fallback = stageCodeMap[normalized];
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return stageId;
}

/// Lazy incremental rendering state from `useInfiniteSlice.ts`.
class InfiniteSlice {
  InfiniteSlice({required this.initialCount, required this.batchSize})
      : visibleCount = initialCount;

  final int initialCount;
  final int batchSize;
  int visibleCount;

  /// `reset()`: back to the first page for a new source list.
  void reset(int sourceLength) {
    visibleCount = initialCount < sourceLength ? initialCount : sourceLength;
  }

  /// `loadMore()`: returns whether anything was added.
  bool loadMore(int sourceLength) {
    if (visibleCount >= sourceLength) {
      return false;
    }
    final next = visibleCount + batchSize;
    visibleCount = next < sourceLength ? next : sourceLength;
    return true;
  }

  int visibleLength(int sourceLength) {
    return visibleCount < sourceLength ? visibleCount : sourceLength;
  }

  bool hasMore(int sourceLength) => visibleCount < sourceLength;
}
