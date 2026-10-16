import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'home_region_sync.dart';
import '../shared/region_select.dart';

/// Bottom block of the PC home sidebar (`PcHome.dc.html`): data region / UI
/// language select, the sync status line and the settings link. The refresh
/// button lives in the page's data card.
///
/// The shell lays the sidebar out with `IntrinsicHeight`, so nothing in here
/// may need a `LayoutBuilder`.
class HomeSidebarPanel extends ConsumerWidget {
  const HomeSidebarPanel({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    // Transparent Material: ink splashes and the region popup need one, and
    // the shell does not provide it around the sidebar.
    return Material(
      type: MaterialType.transparency,
      child: _panel(context, i18n),
    );
  }

  Widget _panel(BuildContext context, NexusI18n i18n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RdColors.hairline)),
      ),
      child: Column(
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
          const SizedBox(height: 12),
          const HomeSyncStatusLine(),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            child: InkWell(
              key: const Key('home-sidebar-settings'),
              borderRadius: BorderRadius.circular(RdRadii.control),
              onTap: onOpenSettings,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: RdColors.text2,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      i18n.t('shell.nav.settings'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: RdColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
