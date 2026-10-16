import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/operator.dart';
import '../../domain/user_data.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../services/operator_service.dart';
import '../../services/plan_cost_service.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../plan/plan_totals.dart';
import '../shared/number_format.dart';

/// How many planned operators the home card lists before "+N more": the
/// phone card stacks them, the PC card sets them beside the farming notice.
const _plannedPreviewCount = 3;
const _plannedPreviewCountWide = 2;

/// One operator of the plan as the home page lists it.
class HomePlannedOperator {
  const HomePlannedOperator({required this.summary, required this.plan});

  final OperatorSummary summary;

  /// Resolved plan (defaults filled in), so the route label matches the
  /// operator plan page.
  final UserPlanOperator plan;
}

/// Plan totals of the home summary, computed with the same services and
/// inputs as the plan page's summary tab (`plan_cost_service.dart`).
class HomePlanSummary {
  const HomePlanSummary({
    this.operators = const [],
    this.totals,
    this.farming,
    this.lmdShortage = 0,
  });

  final List<HomePlannedOperator> operators;
  final PlanAggregateBreakdown? totals;
  final PlanFarmingEstimate? farming;
  final double lmdShortage;

  bool get isEmpty => operators.isEmpty;
}

/// Loads the user's plan for the selected region. Nothing but the user data
/// is read when the plan is empty.
final homePlanSummaryProvider =
    FutureProvider.autoDispose<HomePlanSummary>((ref) async {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  final operatorService = ref.watch(operatorServiceProvider);
  final itemService = ref.watch(itemServiceProvider);
  final costService = ref.watch(planCostServiceProvider);

  final plan = await ref.watch(userDataServiceProvider).getUserPlan();
  if (plan.selectedOperatorIds.isEmpty) {
    return const HomePlanSummary();
  }

  final operators =
      await operatorService.listOperators(OperatorQuery(region: region));
  final byId = {for (final operator in operators) operator.id: operator};
  // Same filter as the plan page: ids missing from this region are skipped.
  final ids = plan.selectedOperatorIds.where(byId.containsKey).toList();
  if (ids.isEmpty) {
    return const HomePlanSummary();
  }

  final detailsFuture = Future.wait([
    for (final id in ids) operatorService.getOperatorDetail(region, id),
  ]);
  final itemsFuture = itemService.listItems(ItemQuery(region: region));
  final details = (await detailsFuture).whereType<OperatorDetail>().toList();
  final items = await itemsFuture;
  final itemsById = {for (final item in items) item.itemId: item};

  final entries = resolvePlanEntries(costService, details, plan);
  if (entries.isEmpty) {
    return const HomePlanSummary();
  }
  final totals = PlanTotals.aggregate(costService, entries, itemsById);

  return HomePlanSummary(
    operators: [
      for (final entry in entries)
        HomePlannedOperator(summary: byId[entry.detail.id]!, plan: entry.plan),
    ],
    totals: totals.breakdown,
    farming: totals.farming,
    lmdShortage: totals.lmdShortage,
  );
});

/// "육성 계획 요약" card with the planned operators. [compact] is the phone
/// variant (two stats, everything stacked); PC shows three stats and the
/// planned operators beside the farming notice.
class HomePlanSummaryCard extends ConsumerWidget {
  const HomePlanSummaryCard({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final async = ref.watch(homePlanSummaryProvider);

    final header = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              i18n.t('rd.home.plan.title'),
              style: RdText.sectionTitle,
            ),
          ),
        ),
        _HomeLink(
          key: const Key('home-open-plan'),
          label: compact
              ? i18n.t('rd.home.plan.openShort')
              : i18n.t('common.openPlan'),
          onTap: () => context.push('/plan'),
        ),
      ],
    );

    final List<Widget> body = async.when(
      // A static glyph, not a spinner: when the data never arrives (widget
      // tests on real file services) an endless animation would keep every
      // `pumpAndSettle` on the app's start page from settling.
      loading: () => [
        RdStatePanel(
          kind: RdStateKind.loading,
          layout: RdStateLayout.inline,
          leading: const Icon(
            Icons.hourglass_empty_rounded,
            size: 16,
            color: RdColors.accent,
          ),
          title: i18n.t('rd.home.plan.loading'),
        ),
      ],
      error: (error, _) => [
        RdStatePanel(
          kind: RdStateKind.error,
          layout: RdStateLayout.inline,
          title: i18n.t('rd.home.plan.errorTitle'),
          message: '$error',
        ),
      ],
      data: (summary) {
        if (summary.isEmpty) {
          return [
            // The header's "open plan" link is the way to add operators.
            RdStatePanel(
              kind: RdStateKind.empty,
              layout: RdStateLayout.inline,
              title: i18n.t('rd.home.plan.emptyTitle'),
              message: i18n.t('rd.home.plan.emptyDescription'),
            ),
          ];
        }
        final totals = summary.totals!;
        final farming = summary.farming!;
        final stats = [
          if (!compact)
            _Stat(
              label: i18n.t('rd.home.plan.statOperators'),
              value: formatWholeNumber(totals.operatorCount),
            ),
          _Stat(
            label: i18n.t('rd.home.plan.statExp'),
            value: formatWholeNumber(farming.exp),
          ),
          _Stat(
            label: i18n.t('rd.home.plan.statLmd'),
            value: formatWholeNumber(farming.lmd),
          ),
        ];
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: _StatTile(stat: stats[i], compact: compact),
                ),
              ],
            ],
          ),
          ..._planBody(
            i18n,
            summary,
            compact: compact,
          ),
        ];
      },
    );

    return RdCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          for (final child in body) ...[
            SizedBox(height: compact ? 10 : 12),
            child,
          ],
        ],
      ),
    );
  }

  /// Farming notice and planned operators under the stats.
  List<Widget> _planBody(
    NexusI18n i18n,
    HomePlanSummary summary, {
    required bool compact,
  }) {
    final totals = summary.totals!;
    final farming = summary.farming!;
    final Widget? notice;
    if (!totals.valid) {
      notice = RdNotice(
        tone: RdNoticeTone.warn,
        text: i18n.t('rd.home.plan.invalid'),
      );
    } else if (farming.totalSanity > 0) {
      notice = RdNotice(
        tone: summary.lmdShortage > 0 ? RdNoticeTone.warn : RdNoticeTone.info,
        text: [
          if (summary.lmdShortage > 0)
            i18n.t('rd.home.plan.lmdShortage', {
              'count': formatWholeNumber(summary.lmdShortage),
            }),
          if (farming.lmdStage.runs > 0)
            i18n.t('rd.home.plan.stageRuns', {
              'stage': farming.lmdStage.code,
              'count': formatWholeNumber(farming.lmdStage.runs),
            }),
          if (farming.expStage.runs > 0)
            i18n.t('rd.home.plan.stageRuns', {
              'stage': farming.expStage.code,
              'count': formatWholeNumber(farming.expStage.runs),
            }),
          i18n.t('rd.home.plan.sanity', {
            'count': formatWholeNumber(farming.totalSanity),
          }),
        ].join(' · '),
      );
    } else {
      notice = null;
    }
    if (compact) {
      return [
        if (notice != null) notice,
        HomePlannedOperatorList(summary: summary, compact: true),
      ];
    }
    final planned = HomePlannedOperatorList(
      summary: summary,
      compact: true,
      previewCount: _plannedPreviewCountWide,
    );
    if (notice == null) {
      return [planned];
    }
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [notice!, const SizedBox(height: 12), planned],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: notice!),
              const SizedBox(width: 12),
              SizedBox(width: 260, child: planned),
            ],
          );
        },
      ),
    ];
  }
}

/// Planned operator rows (portrait, name, current → target, rarity); each
/// opens that operator's plan page.
class HomePlannedOperatorList extends ConsumerWidget {
  const HomePlannedOperatorList({
    required this.summary,
    required this.compact,
    this.previewCount = _plannedPreviewCount,
    super.key,
  });

  final HomePlanSummary summary;
  final bool compact;

  /// Rows listed before "+N more".
  final int previewCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final shown = summary.operators.take(previewCount).toList();
    final rest = summary.operators.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PlannedOperatorRow(operator: shown[i], compact: compact),
        ],
        if (rest > 0) ...[
          const SizedBox(height: 8),
          Text(
            i18n.t('rd.home.plan.more', {'count': rest}),
            style: RdText.muted,
          ),
        ],
      ],
    );
  }
}

class _PlannedOperatorRow extends StatelessWidget {
  const _PlannedOperatorRow({required this.operator, required this.compact});

  final HomePlannedOperator operator;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final summary = operator.summary;
    final current = operator.plan.current;
    final target = operator.plan.target;
    final route = 'E${current.elite} Lv.${current.level} → '
        'E${target.elite} Lv.${target.level}';
    return Semantics(
      button: true,
      label: '${summary.name}, $route, ★${summary.rarity}',
      excludeSemantics: true,
      child: Material(
        color: RdColors.inner,
        borderRadius: BorderRadius.circular(RdRadii.inner),
        child: InkWell(
          key: Key('home-planned-${summary.id}'),
          borderRadius: BorderRadius.circular(RdRadii.inner),
          onTap: () => context.push('/plan/${summary.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                RdPortrait(
                  charId: summary.id,
                  name: summary.name,
                  size: compact ? 44 : 56,
                  radius: RdRadii.control,
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: RdColors.text,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        route,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          color: RdColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '★${summary.rarity}',
                  style: const TextStyle(fontSize: 13, color: RdColors.rarity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.compact});

  final _Stat stat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RdColors.inner,
        borderRadius: BorderRadius.circular(RdRadii.inner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: RdColors.text3),
          ),
          SizedBox(height: compact ? 2 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              style: RdText.mono(fontSize: compact ? 17 : 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accent text link ("계획 열기 →"), 44px tall for touch.
class _HomeLink extends StatelessWidget {
  const _HomeLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(RdRadii.small),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Align(
              widthFactor: 1,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: RdColors.accentHover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
