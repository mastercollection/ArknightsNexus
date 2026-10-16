import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../shared/region_operator_counts.dart';
import '../shared/region_sync.dart';

/// Status of [regionSyncStatusProvider] / [regionSyncControllerProvider] for the
/// status lines.
enum HomeSyncState { loading, syncing, ready, needed }

class HomeSyncView {
  const HomeSyncView(this.state, [this.counts]);

  final HomeSyncState state;

  /// Operators of the ready region; null when it has none or they are still
  /// being counted.
  final RegionOperatorCounts? counts;

  static HomeSyncView watch(WidgetRef ref) {
    if (ref.watch(regionSyncControllerProvider) ||
        ref.watch(regionEnsureProvider).isLoading) {
      return const HomeSyncView(HomeSyncState.syncing);
    }
    return ref.watch(regionSyncStatusProvider).when(
          data: (status) => status?.isReady == true
              ? HomeSyncView(
                  HomeSyncState.ready,
                  ref.watch(regionOperatorCountsProvider).valueOrNull ??
                      // The summaries are still being read: the snapshot's
                      // total stands in until they are.
                      (status!.operatorCount > 0
                          ? RegionOperatorCounts(
                              native: status.operatorCount,
                              unreleased: 0,
                            )
                          : null),
                )
              : const HomeSyncView(HomeSyncState.needed),
          error: (_, __) => const HomeSyncView(HomeSyncState.needed),
          loading: () => const HomeSyncView(HomeSyncState.loading),
        );
  }

  String label(NexusI18n i18n) => switch (state) {
        HomeSyncState.loading => i18n.t('rd.home.sync.loading'),
        HomeSyncState.syncing => i18n.t('common.syncing'),
        HomeSyncState.ready => switch (counts) {
            final counts? => i18n.t('rd.home.sync.readyCount', {
                'count': formatOperatorCounts(i18n, counts),
              }),
            null => i18n.t('home.settings.syncReady'),
          },
        HomeSyncState.needed => i18n.t('rd.home.sync.needed'),
      };

  Color get dotColor => switch (state) {
        HomeSyncState.syncing => RdColors.accent,
        HomeSyncState.ready => RdColors.success,
        HomeSyncState.needed => RdColors.warning,
        HomeSyncState.loading => RdColors.text3,
      };
}

/// "● 준비됨 · 415명 · 미실장 17명" status line (`role="status"`).
class HomeSyncStatusLine extends ConsumerWidget {
  const HomeSyncStatusLine({
    this.withRegion = false,
    this.fontSize = 13,
    super.key,
  });

  /// Prefixes the region code ("KR 데이터 · …", the mobile header variant).
  final bool withRegion;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final view = HomeSyncView.watch(ref);
    final status = view.label(i18n);
    final text = withRegion
        ? i18n.t('rd.home.sync.regionStatus', {
            'region': regionLabels[ref.watch(regionProvider)],
            'status': status,
          })
        : status;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: view.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              key: const Key('home-sync-status'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: RdColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled sync button of the PC sidebar ("⟳ 새로고침").
class HomeSyncButton extends ConsumerWidget {
  const HomeSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final syncing = ref.watch(regionSyncControllerProvider);
    final foreground = syncing ? RdColors.text3 : RdColors.text;
    Widget icon = Icon(Icons.refresh, size: 15, color: foreground);
    if (syncing) {
      icon = RdSpin(child: icon);
    }
    return Tooltip(
      message: i18n.t('rd.home.sync.tooltip'),
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: !syncing,
        excludeSemantics: true,
        label: i18n.t('rd.home.sync.tooltip'),
        child: Material(
          color: syncing ? Colors.transparent : RdColors.surface3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.control),
            side: const BorderSide(color: RdColors.border),
          ),
          child: InkWell(
            key: const Key('home-sync-button'),
            borderRadius: BorderRadius.circular(RdRadii.control),
            onTap: syncing ? null : () => runRegionSync(context, ref),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Text(
                    syncing
                        ? i18n.t('rd.home.sync.actionBusy')
                        : i18n.t('rd.home.sync.action'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
