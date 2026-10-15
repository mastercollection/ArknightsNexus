import 'dart:math' as math;

import '../../domain/item.dart';
import '../../domain/operator.dart';
import '../../domain/user_data.dart';
import '../../services/plan_cost_service.dart';

/// Cost totals of a plan as the plan pages and the home summary show them:
/// the cost breakdown, its farming estimate and the LMD the inventory lacks.
class PlanTotals<B extends PlanCostBreakdown> {
  const PlanTotals._({
    required this.entries,
    required this.breakdown,
    required this.farming,
    required this.lmdShortage,
  });

  /// Aggregate over several planned operators (`plan/index.vue` summary,
  /// home). Missing plans fall back to the operator's defaults, so the
  /// numbers match the operator plan page.
  static PlanTotals<PlanAggregateBreakdown> aggregate(
    PlanCostService costService,
    List<PlanCostEntry> entries,
    Map<String, ItemEntry> itemsById,
  ) {
    return _withFarming(
      costService,
      entries,
      costService.aggregatePlanCostsWithItems(entries, itemsById),
      itemsById,
    );
  }

  /// Totals of one operator's plan (the operator plan page aside).
  static PlanTotals<PlanCostBreakdown> single(
    PlanCostService costService,
    OperatorDetail detail,
    UserPlanOperator plan,
    Map<String, ItemEntry> itemsById,
  ) {
    return _withFarming(
      costService,
      [PlanCostEntry(detail: detail, plan: plan)],
      costService.calculatePlanCostsWithItems(detail, plan, itemsById),
      itemsById,
    );
  }

  static PlanTotals<T> _withFarming<T extends PlanCostBreakdown>(
    PlanCostService costService,
    List<PlanCostEntry> entries,
    T breakdown,
    Map<String, ItemEntry> itemsById,
  ) {
    final farming = costService.estimatePlanFarming(breakdown);
    final owned = itemsById[farming.lmdItem?.id ?? lmdItemId]?.ownedCount ?? 0;
    return PlanTotals._(
      entries: entries,
      breakdown: breakdown,
      farming: farming,
      lmdShortage: math.max(0, farming.lmd - owned),
    );
  }

  /// The planned operators the totals cover, in plan order.
  final List<PlanCostEntry> entries;
  final B breakdown;
  final PlanFarmingEstimate farming;

  /// `max(0, LMD required - LMD owned)`.
  final double lmdShortage;

  /// Item of the LMD line: the material entry when there is one.
  String get lmdId => farming.lmdItem?.id ?? lmdItemId;

  bool get showExp => farming.exp > 0;
  bool get showLmd => farming.lmd > 0;
}

/// [PlanCostEntry] per detail, with its saved plan resolved against the
/// operator's defaults.
List<PlanCostEntry> resolvePlanEntries(
  PlanCostService costService,
  Iterable<OperatorDetail> details,
  UserPlan plan,
) {
  return [
    for (final detail in details)
      PlanCostEntry(
        detail: detail,
        plan: costService.resolvePlanOperator(
          detail,
          costService.getPlanByOperatorId(plan, detail.id),
        ),
      ),
  ];
}
