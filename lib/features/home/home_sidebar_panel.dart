import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'home_region_sync.dart';
import '../shared/region_select.dart';

/// Bottom block of the PC home sidebar (`Main.dc.html`): data region / UI
/// language select, sync status with a sync button, and the settings link.
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              i18n.t('rd.home.region.label'),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.96,
                color: RdColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RdRegionSelect(semanticLabel: i18n.t('rd.home.region.label')),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: HomeSyncStatusLine()),
              SizedBox(width: 8),
              HomeSyncButton(),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            child: InkWell(
              key: const Key('home-sidebar-settings'),
              borderRadius: BorderRadius.circular(RdRadii.small),
              onTap: onOpenSettings,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_outlined,
                      size: 16,
                      color: RdColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      i18n.t('shell.nav.settings'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: RdColors.secondary,
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
