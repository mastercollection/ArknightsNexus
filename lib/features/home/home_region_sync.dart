import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../shared/region_sync.dart';

/// Status of [regionSyncStatusProvider] / [regionSyncControllerProvider] for the
/// status lines.
enum HomeSyncState { loading, syncing, ready, needed }

class HomeSyncView {
  const HomeSyncView(this.state, this.operatorCount);

  final HomeSyncState state;
  final int operatorCount;

  static HomeSyncView watch(WidgetRef ref) {
    if (ref.watch(regionSyncControllerProvider)) {
      return const HomeSyncView(HomeSyncState.syncing, 0);
    }
    return ref.watch(regionSyncStatusProvider).when(
          data: (status) => status?.isReady == true
              ? HomeSyncView(HomeSyncState.ready, status!.operatorCount)
              : const HomeSyncView(HomeSyncState.needed, 0),
          error: (_, __) => const HomeSyncView(HomeSyncState.needed, 0),
          loading: () => const HomeSyncView(HomeSyncState.loading, 0),
        );
  }

  String label(NexusI18n i18n) => switch (state) {
        HomeSyncState.loading => i18n.t('rd.home.sync.loading'),
        HomeSyncState.syncing => i18n.t('rd.home.sync.syncing'),
        HomeSyncState.ready => operatorCount > 0
            ? i18n.t('rd.home.sync.readyCount', {'count': operatorCount})
            : i18n.t('rd.home.sync.ready'),
        HomeSyncState.needed => i18n.t('rd.home.sync.needed'),
      };

  Color get dotColor => switch (state) {
        HomeSyncState.syncing => RdColors.accent,
        HomeSyncState.ready => RdColors.success,
        HomeSyncState.needed => RdColors.gold,
        HomeSyncState.loading => RdColors.muted,
      };
}

/// "● 준비됨 · 415명" status line (`role="status"`).
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
                color: RdColors.secondary2,
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
    final foreground = syncing ? RdColors.placeholder : RdColors.linkText;
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
          color: syncing ? Colors.transparent : RdColors.linkFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.small),
            side: BorderSide(
              color: syncing ? RdColors.white8 : RdColors.tonalBorder,
            ),
          ),
          child: InkWell(
            key: const Key('home-sync-button'),
            borderRadius: BorderRadius.circular(RdRadii.small),
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
                      fontWeight: FontWeight.w700,
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
