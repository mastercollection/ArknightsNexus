import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../shared/region_data_label.dart';
import '../shared/region_operator_counts.dart';
import '../shared/region_select.dart';
import '../shared/region_sync.dart';

/// Status of [regionSyncStatusProvider] / [regionSyncControllerProvider] for the
/// status lines.
enum HomeSyncState { loading, syncing, ready, needed }

class HomeSyncView {
  const HomeSyncView(this.state, {this.counts, this.status});

  final HomeSyncState state;

  /// Operators of the ready region; null when it has none or they are still
  /// being counted.
  final RegionOperatorCounts? counts;

  /// Cached sync status of the region (data version, fetch time); kept while
  /// a sync runs so the version stays on screen.
  final RegionSyncStatus? status;

  static HomeSyncView watch(WidgetRef ref) {
    final statusAsync = ref.watch(regionSyncStatusProvider);
    final cached = statusAsync.valueOrNull;
    if (ref.watch(regionSyncControllerProvider) ||
        ref.watch(regionEnsureProvider).isLoading) {
      return HomeSyncView(HomeSyncState.syncing, status: cached);
    }
    return statusAsync.when(
      data: (status) => status?.isReady == true
          ? HomeSyncView(
              HomeSyncState.ready,
              status: status,
              counts: ref.watch(regionOperatorCountsProvider).valueOrNull ??
                  // The summaries are still being read: the snapshot's
                  // total stands in until they are.
                  (status!.operatorCount > 0
                      ? RegionOperatorCounts(
                          native: status.operatorCount,
                          unreleased: 0,
                        )
                      : null),
            )
          : HomeSyncView(HomeSyncState.needed, status: status),
      error: (_, __) => const HomeSyncView(HomeSyncState.needed),
      loading: () => const HomeSyncView(HomeSyncState.loading),
    );
  }

  /// Short state word ("준비됨", "동기화 필요", …).
  String stateLabel(NexusI18n i18n) => switch (state) {
        HomeSyncState.loading => i18n.t('rd.home.sync.loading'),
        HomeSyncState.syncing => i18n.t('common.syncing'),
        HomeSyncState.ready => i18n.t('home.settings.syncReady'),
        HomeSyncState.needed => i18n.t('rd.home.sync.needed'),
      };

  /// Local time of the last sync, if the region has been synced.
  String? syncTime() => formatSyncTime(status?.fetchedAt);

  Color get dotColor => switch (state) {
        HomeSyncState.syncing => RdColors.accent,
        HomeSyncState.ready => RdColors.success,
        HomeSyncState.needed => RdColors.warning,
        HomeSyncState.loading => RdColors.text3,
      };
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// "● KR 52.0.0 · 415명 · 미실장 17명" status line (`role="status"`) of the
/// phone home and the PC sidebar; [showTime] adds the last sync time at the
/// end of the row (phones).
class HomeSyncStatusLine extends ConsumerWidget {
  const HomeSyncStatusLine({
    this.fontSize = 12,
    this.showTime = false,
    super.key,
  });

  final double fontSize;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final view = HomeSyncView.watch(ref);
    final data = regionDataLabel(ref.watch(regionProvider), view.status);
    final style = TextStyle(fontSize: fontSize, color: RdColors.text2);
    final counts = view.counts;
    final Widget text = view.state == HomeSyncState.ready && counts != null
        ? OperatorCountsText(
            key: const Key('home-sync-status'),
            i18n: i18n,
            counts: counts,
            prefix: '$data · ',
            maxLines: 2,
            style: style,
          )
        : Text(
            '$data · ${view.stateLabel(i18n)}',
            key: const Key('home-sync-status'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
    final time = showTime ? view.syncTime() : null;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          _Dot(view.dotColor),
          const SizedBox(width: 8),
          Expanded(child: text),
          if (time != null) ...[
            const SizedBox(width: 8),
            Text(
              time,
              key: const Key('home-sync-time'),
              style: TextStyle(fontSize: fontSize, color: RdColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

/// "데이터" card of the PC home: state, region data version, operator counts,
/// last sync time and the refresh (sync) button. [showRegionSelect] adds the
/// region select where there is no sidebar (medium width).
class HomeDataCard extends ConsumerWidget {
  const HomeDataCard({this.showRegionSelect = false, super.key});

  final bool showRegionSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final view = HomeSyncView.watch(ref);
    final region = ref.watch(regionProvider);
    final counts = view.counts;
    const labelStyle = TextStyle(fontSize: 13, color: RdColors.text3);
    TableRow row(String label, Widget value) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: Text(label, style: labelStyle),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 8), child: value),
          ],
        );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  i18n.t('rd.home.data.title'),
                  style: RdText.sectionTitle,
                ),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(view.dotColor),
                  const SizedBox(width: 6),
                  Text(
                    view.stateLabel(i18n),
                    key: const Key('home-sync-state'),
                    style: TextStyle(
                      fontSize: 12,
                      color: view.state == HomeSyncState.ready
                          ? RdColors.success
                          : RdColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          regionDataLabel(region, view.status),
          key: const Key('home-data-version'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RdText.mono(fontSize: 22),
        ),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          children: [
            row(
              i18n.t('rd.home.plan.statOperators'),
              counts == null
                  ? const Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: RdColors.text2),
                    )
                  : OperatorCountsText(
                      key: const Key('home-data-counts'),
                      i18n: i18n,
                      counts: counts,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: RdColors.text,
                      ),
                    ),
            ),
            row(
              i18n.t('rd.home.data.lastSync'),
              Text(
                view.syncTime() ?? '—',
                key: const Key('home-data-time'),
                style: const TextStyle(fontSize: 13, color: RdColors.text2),
              ),
            ),
          ],
        ),
      ],
    );
    if (!showRegionSelect) {
      return RdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [info, const SizedBox(height: 6), const HomeSyncButton()],
        ),
      );
    }
    // Medium width: the card spans the column, so the region select and the
    // refresh button get their own column beside the facts when they fit.
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            i18n.t('rd.home.region.label'),
            style: const TextStyle(fontSize: 12, color: RdColors.text3),
          ),
        ),
        const SizedBox(height: 6),
        RdRegionSelect(semanticLabel: i18n.t('rd.home.region.label')),
        const SizedBox(height: 10),
        const HomeSyncButton(),
      ],
    );
    return RdCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 6), controls],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: info),
              const SizedBox(width: 24),
              SizedBox(width: 280, child: controls),
            ],
          );
        },
      ),
    );
  }
}

/// "⟳ 새로고침" button of the data card: syncs the selected region.
class HomeSyncButton extends ConsumerWidget {
  const HomeSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final syncing = ref.watch(regionSyncControllerProvider);
    return Tooltip(
      message: i18n.t('rd.home.sync.tooltip'),
      waitDuration: const Duration(milliseconds: 400),
      child: RdButton(
        key: const Key('home-sync-button'),
        label: syncing
            ? i18n.t('rd.home.sync.actionBusy')
            : i18n.t('rd.home.sync.action'),
        icon: Icons.refresh,
        busy: syncing,
        expand: true,
        height: 40,
        onPressed: () => runRegionSync(context, ref),
      ),
    );
  }
}

/// 44px icon-only sync button (mobile header).
class HomeSyncIconButton extends ConsumerWidget {
  const HomeSyncIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final syncing = ref.watch(regionSyncControllerProvider);
    return RdIconButton(
      key: const Key('home-sync-button'),
      icon: Icons.refresh,
      tooltip: syncing
          ? i18n.t('rd.home.sync.actionBusy')
          : i18n.t('rd.home.sync.tooltip'),
      spinning: syncing,
      onPressed: syncing ? null : () => runRegionSync(context, ref),
    );
  }
}
