import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data_sources/region_code.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';

/// Region options with their native language name, as the canvas lists them
/// ("KR · 한국어"). The names are endonyms, so they do not follow the locale.
const homeRegionLanguageLabels = <RegionCode, String>{
  RegionCode.kr: 'KR · 한국어',
  RegionCode.cn: 'CN · 简体中文',
  RegionCode.jp: 'JP · 日本語',
  RegionCode.tw: 'TW · 繁體中文',
  RegionCode.en: 'EN · English',
};

/// Sync status of the selected region (Vue `index.vue` loads it next to the
/// featured operators). Reloads on region change and after a manual sync.
final homeSyncStatusProvider =
    FutureProvider.autoDispose<RegionSyncStatus?>((ref) {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(regionSyncServiceProvider).getRegionSyncStatus(region);
});

/// Force sync of the home page (`forceSync` in `index.vue`). Shared by the PC
/// sidebar panel and the in-page controls so both show the same busy state.
/// The state is `true` while a sync runs.
class HomeSyncController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Syncs the selected region; returns the error, or `null` on success (or
  /// when a sync is already running).
  Future<Object?> sync() async {
    if (state) {
      return null;
    }
    state = true;
    final region = ref.read(regionProvider);
    try {
      await ref
          .read(regionSyncServiceProvider)
          .syncRegion(region)
          .drain<void>();
      ref.read(dataRevisionProvider.notifier).state++;
      return null;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('home force sync failed', error, stackTrace);
      return error;
    } finally {
      state = false;
    }
  }
}

final homeSyncControllerProvider =
    NotifierProvider<HomeSyncController, bool>(HomeSyncController.new);

/// Runs [HomeSyncController.sync] and shows its error as a toast.
Future<void> runHomeSync(BuildContext context, WidgetRef ref) async {
  final error = await ref.read(homeSyncControllerProvider.notifier).sync();
  if (error != null && context.mounted) {
    showNexusMessage(context, '$error', type: NexusMessageType.error);
  }
}

/// Status of [homeSyncStatusProvider] / [homeSyncControllerProvider] for the
/// status lines.
enum HomeSyncState { loading, syncing, ready, needed }

class HomeSyncView {
  const HomeSyncView(this.state, this.operatorCount);

  final HomeSyncState state;
  final int operatorCount;

  static HomeSyncView watch(WidgetRef ref) {
    if (ref.watch(homeSyncControllerProvider)) {
      return const HomeSyncView(HomeSyncState.syncing, 0);
    }
    return ref.watch(homeSyncStatusProvider).when(
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
    final syncing = ref.watch(homeSyncControllerProvider);
    final foreground = syncing ? RdColors.placeholder : const Color(0xFFDBE8FF);
    Widget icon = Icon(Icons.refresh, size: 15, color: foreground);
    if (syncing) {
      icon = _Spinning(child: icon);
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
          color: syncing ? Colors.transparent : const Color(0x1F85B6FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.small),
            side: BorderSide(
              color:
                  syncing ? const Color(0x14FFFFFF) : const Color(0x6685B6FF),
            ),
          ),
          child: InkWell(
            key: const Key('home-sync-button'),
            borderRadius: BorderRadius.circular(RdRadii.small),
            onTap: syncing ? null : () => runHomeSync(context, ref),
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
    final syncing = ref.watch(homeSyncControllerProvider);
    return RdIconButton(
      key: const Key('home-sync-button'),
      icon: Icons.refresh,
      tooltip: syncing
          ? i18n.t('rd.home.sync.actionBusy')
          : i18n.t('rd.home.sync.tooltip'),
      spinning: syncing,
      onPressed: syncing ? null : () => runHomeSync(context, ref),
    );
  }
}

/// Region select of the redesign: the data region, which also sets the UI
/// language (`useRegionPreference`). Not persisted, like the Tauri app.
class RdRegionSelect extends ConsumerWidget {
  const RdRegionSelect({
    required this.semanticLabel,
    this.codesOnly = false,
    this.height = 40,
    this.fontSize = 14,
    super.key,
  });

  final String semanticLabel;

  /// Shows "KR" instead of "KR · 한국어" in the closed select (the mobile
  /// header); the menu always lists the language names.
  final bool codesOnly;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionProvider);
    final label =
        codesOnly ? regionLabels[region]! : homeRegionLanguageLabels[region]!;
    return Semantics(
      label: semanticLabel,
      value: homeRegionLanguageLabels[region],
      child: PopupMenuButton<RegionCode>(
        key: const Key('region-select'),
        tooltip: semanticLabel,
        initialValue: region,
        color: RdColors.inner2,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.control),
          side: const BorderSide(color: RdColors.line3),
        ),
        onSelected: (next) {
          if (next != ref.read(regionProvider)) {
            ref.read(regionProvider.notifier).state = next;
          }
        },
        itemBuilder: (context) => [
          for (final option in regionOptions)
            PopupMenuItem<RegionCode>(
              value: option,
              height: 44,
              child: Text(
                homeRegionLanguageLabels[option]!,
                style: TextStyle(
                  fontSize: 14,
                  color: option == region ? RdColors.accent : RdColors.text,
                  fontWeight:
                      option == region ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
        child: Container(
          height: height,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF121A2C),
            borderRadius: BorderRadius.circular(RdRadii.small),
            border: Border.all(color: RdColors.line3),
          ),
          child: Row(
            mainAxisSize: codesOnly ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (codesOnly)
                Text(
                  label,
                  style: TextStyle(fontSize: fontSize, color: RdColors.text),
                )
              else
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fontSize, color: RdColors.text),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: RdColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinning extends StatefulWidget {
  const _Spinning({required this.child});

  final Widget child;

  @override
  State<_Spinning> createState() => _SpinningState();
}

class _SpinningState extends State<_Spinning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
