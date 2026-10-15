import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/operator.dart';
import '../../domain/user_data.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../services/operator_service.dart';
import '../../services/plan_cost_service.dart';
import '../../ui/redesign/rd_widgets.dart';

const _lmdItemId = '4001';

/// How many planned operators the home cards list before "+N more".
const _plannedPreviewCount = 3;

final _numberFormat = NumberFormat('#,##0', 'en_US');

String _formatNumber(num value) => _numberFormat.format(value.ceil());

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

  final entries = [
    for (final detail in details)
      PlanCostEntry(
        detail: detail,
        plan: costService.resolvePlanOperator(
          detail,
          costService.getPlanByOperatorId(plan, detail.id),
        ),
      ),
  ];
  if (entries.isEmpty) {
    return const HomePlanSummary();
  }
  final totals = costService.aggregatePlanCostsWithItems(entries, itemsById);
  final farming = costService.estimatePlanFarming(totals);
  final owned = itemsById[farming.lmdItem?.id ?? _lmdItemId]?.ownedCount ?? 0;

  return HomePlanSummary(
    operators: [
      for (final entry in entries)
        HomePlannedOperator(summary: byId[entry.detail.id]!, plan: entry.plan),
    ],
    totals: totals,
    farming: farming,
    lmdShortage: math.max(0, farming.lmd - owned),
  );
});

/// "육성 계획 요약" card. [compact] is the phone variant (two stats, the
/// planned operators inside the same card).
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
              style: TextStyle(
                fontSize: compact ? 17 : 18,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
          ),
        ),
        _HomeLink(
          key: const Key('home-open-plan'),
          label: compact
              ? i18n.t('rd.home.plan.openShort')
              : i18n.t('rd.home.plan.open'),
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
              value: _formatNumber(totals.operatorCount),
            ),
          _Stat(
            label: i18n.t('rd.home.plan.statExp'),
            value: _formatNumber(farming.exp),
          ),
          _Stat(
            label: i18n.t('rd.home.plan.statLmd'),
            value: _formatNumber(farming.lmd),
          ),
        ];
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: _StatTile(stat: stats[i], compact: compact),
                ),
              ],
            ],
          ),
          if (!totals.valid)
            RdNotice(
              tone: RdNoticeTone.warn,
              text: i18n.t('rd.home.plan.invalid'),
            )
          else if (farming.totalSanity > 0)
            RdNotice(
              tone: summary.lmdShortage > 0
                  ? RdNoticeTone.warn
                  : RdNoticeTone.info,
              text: [
                if (summary.lmdShortage > 0)
                  i18n.t('rd.home.plan.lmdShortage', {
                    'count': _formatNumber(summary.lmdShortage),
                  }),
                if (farming.lmdStage.runs > 0)
                  i18n.t('rd.home.plan.stageRuns', {
                    'stage': farming.lmdStage.code,
                    'count': _formatNumber(farming.lmdStage.runs),
                  }),
                if (farming.expStage.runs > 0)
                  i18n.t('rd.home.plan.stageRuns', {
                    'stage': farming.expStage.code,
                    'count': _formatNumber(farming.expStage.runs),
                  }),
                i18n.t('rd.home.plan.sanity', {
                  'count': _formatNumber(farming.totalSanity),
                }),
              ].join(' · '),
            ),
          if (compact) HomePlannedOperatorList(summary: summary, compact: true),
        ];
      },
    );

    return RdCard(
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          for (final child in body) ...[
            SizedBox(height: compact ? 14 : 18),
            child,
          ],
        ],
      ),
    );
  }
}

/// "계획 중인 오퍼레이터" card of the PC home; only shown when the plan has
/// operators (the summary card carries the empty state).
class HomePlannedOperatorsCard extends ConsumerWidget {
  const HomePlannedOperatorsCard({required this.summary, super.key});

  final HomePlanSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              i18n.t('rd.home.plan.planned'),
              style: RdText.sectionTitle,
            ),
          ),
          const SizedBox(height: 14),
          HomePlannedOperatorList(summary: summary, compact: false),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _HomeLink(
              label: i18n.t('rd.home.plan.addMore'),
              onTap: () => context.push('/plan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Planned operator rows (portrait, name, current → target, rarity); each
/// opens that operator's plan page.
class HomePlannedOperatorList extends ConsumerWidget {
  const HomePlannedOperatorList({
    required this.summary,
    required this.compact,
    super.key,
  });

  final HomePlanSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final shown = summary.operators.take(_plannedPreviewCount).toList();
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
                  radius: 18,
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
                  style: const TextStyle(fontSize: 13, color: RdColors.gold),
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
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: RdColors.muted,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              style: RdText.mono(fontSize: compact ? 18 : 22),
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
                  fontSize: 14,
                  color: RdColors.link,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
