import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/operator_service.dart';
import 'number_format.dart';
import 'region_sync.dart';

/// Operators of the selected region: the ones it has released ([native]) and
/// the ones shown from another region's data until it does ([unreleased]).
class RegionOperatorCounts {
  const RegionOperatorCounts({required this.native, required this.unreleased});

  factory RegionOperatorCounts.of(Iterable<OperatorSummary> operators) {
    var native = 0;
    var unreleased = 0;
    for (final operator in operators) {
      if (operator.isUnreleased) {
        unreleased += 1;
      } else {
        native += 1;
      }
    }
    return RegionOperatorCounts(native: native, unreleased: unreleased);
  }

  final int native;
  final int unreleased;

  int get total => native + unreleased;

  @override
  bool operator ==(Object other) =>
      other is RegionOperatorCounts &&
      other.native == native &&
      other.unreleased == unreleased;

  @override
  int get hashCode => Object.hash(native, unreleased);
}

/// [RegionOperatorCounts] of the selected region's operator summaries.
/// Reloads on region change and after a sync, like
/// [regionSyncStatusProvider]; `null` while the region has no data.
final regionOperatorCountsProvider =
    FutureProvider.autoDispose<RegionOperatorCounts?>((ref) async {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  try {
    await ref.watch(regionEnsureProvider.future);
  } catch (_) {
    // Logged by RegionReadiness; count whatever is cached.
  }
  final operators = await ref
      .watch(operatorServiceProvider)
      .listOperators(OperatorQuery(region: region));
  if (operators.isEmpty) {
    return null;
  }
  return RegionOperatorCounts.of(operators);
});

/// "415명 · 미실장 17명", or "415명" when the region shows no unreleased
/// operators.
String formatOperatorCounts(NexusI18n i18n, RegionOperatorCounts counts) {
  final native = formatWholeNumber(counts.native);
  if (counts.unreleased == 0) {
    return i18n.t('common.operatorCount', {'count': native});
  }
  return i18n.t('common.operatorCountUnreleased', {
    'count': native,
    'unreleased': formatWholeNumber(counts.unreleased),
  });
}
