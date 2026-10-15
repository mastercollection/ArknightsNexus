import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_sidebar_panel.dart';
import '../features/shared/region_sync.dart';
import '../i18n/nexus_i18n.dart';
import '../ui/redesign/rd_widgets.dart';

/// Top-level sections of the app, in navigation order.
enum NexusSection {
  home('/', Icons.home_outlined, 'shell.nav.home', 'shell.nav.home'),
  operators(
    '/operators',
    Icons.diamond_outlined,
    'shell.nav.operators',
    'shell.nav.operators',
  ),
  plan(
    '/plan',
    Icons.view_agenda_outlined,
    'shell.nav.plan',
    'shell.nav.planShort',
  ),
  items(
    '/items',
    Icons.grid_view_outlined,
    'shell.nav.items',
    'shell.nav.items',
  ),
  settings(
    '/settings',
    Icons.settings_outlined,
    'shell.nav.settings',
    'shell.nav.settings',
  );

  const NexusSection(this.path, this.icon, this.labelKey, this.tabLabelKey);

  final String path;
  final IconData icon;
  final String labelKey;
  final String tabLabelKey;

  static NexusSection of(String location) {
    final path = Uri.parse(location).path;
    for (final section in values.skip(1)) {
      if (path == section.path || path.startsWith('${section.path}/')) {
        return section;
      }
    }
    return home;
  }
}

/// Responsive frame around every page (the redesign's navigation):
/// - compact (phones): page + bottom tab bar;
/// - medium/expanded: 76px icon rail + page;
/// - expanded home: the full sidebar with region / sync / settings.
///
/// Rail and tab taps switch section with `go` (the section's root replaces
/// the stack); links inside pages keep pushing, so back returns to them.
/// Back with nothing left to pop climbs to the section root, then home, and
/// only leaves the app from home.
class NexusShell extends ConsumerWidget {
  const NexusShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts the selected region's data check/download with the app.
    ref.listen(regionEnsureProvider, (_, __) {});
    final i18n = ref.watch(i18nProvider);
    final section = NexusSection.of(location);
    final layout = context.rdLayout;
    final atSectionRoot = Uri.parse(location).path == section.path;

    void select(NexusSection target) {
      if (target == section && atSectionRoot) {
        return;
      }
      context.go(target.path);
    }

    Widget body;
    switch (layout) {
      case RdLayout.compact:
        body = Column(
          children: [
            Expanded(child: child),
            _BottomTabs(i18n: i18n, current: section, onSelect: select),
          ],
        );
      case RdLayout.medium:
      case RdLayout.expanded:
        final fullSidebar =
            layout == RdLayout.expanded && section == NexusSection.home;
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fullSidebar)
              _Sidebar(i18n: i18n, current: section, onSelect: select)
            else
              _IconRail(i18n: i18n, current: section, onSelect: select),
            Expanded(child: child),
          ],
        );
    }

    // Only reached when the page stack inside the shell has nothing left to
    // pop: a section page opened directly climbs to its section root, a
    // section root returns home, and home leaves the app.
    return PopScope(
      canPop: section == NexusSection.home && atSectionRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go(atSectionRoot ? NexusSection.home.path : section.path);
        }
      },
      child: Material(color: RdColors.bg, child: body),
    );
  }
}

class _IconRail extends StatelessWidget {
  const _IconRail({
    required this.i18n,
    required this.current,
    required this.onSelect,
  });

  final NexusI18n i18n;
  final NexusSection current;
  final ValueChanged<NexusSection> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(NexusSection section) => _RailButton(
          key: Key('rail-${section.name}'),
          icon: section.icon,
          label: i18n.t(section.labelKey),
          selected: section == current,
          onTap: () => onSelect(section),
        );

    return Semantics(
      container: true,
      label: i18n.t('shell.nav.label'),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: const BoxDecoration(
          color: RdColors.rail,
          border: Border(right: BorderSide(color: RdColors.line)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              for (final section in NexusSection.values)
                if (section != NexusSection.settings) ...[
                  item(section),
                  const SizedBox(height: 8),
                ],
              const Spacer(),
              item(NexusSection.settings),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? RdColors.chipOnFill : Colors.transparent,
          borderRadius: BorderRadius.circular(RdRadii.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(RdRadii.control),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                size: 22,
                color: selected ? RdColors.text : RdColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.i18n,
    required this.current,
    required this.onSelect,
  });

  final NexusI18n i18n;
  final NexusSection current;
  final ValueChanged<NexusSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: i18n.t('shell.nav.label'),
      child: Container(
        width: 256,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: const BoxDecoration(
          color: RdColors.rail,
          border: Border(right: BorderSide(color: RdColors.line)),
        ),
        child: SafeArea(
          right: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const RdAppMark(),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Arknights Nexus',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: RdColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final section in NexusSection.values)
                        if (section != NexusSection.settings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _SidebarLink(
                              key: Key('sidebar-${section.name}'),
                              icon: section.icon,
                              label: i18n.t(section.labelKey),
                              selected: section == current,
                              onTap: () => onSelect(section),
                            ),
                          ),
                      const Spacer(),
                      const SizedBox(height: 28),
                      HomeSidebarPanel(
                        onOpenSettings: () => onSelect(NexusSection.settings),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? RdColors.chipOnFill : Colors.transparent,
        borderRadius: BorderRadius.circular(RdRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.control),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? RdColors.text : RdColors.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? RdColors.text : RdColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.i18n,
    required this.current,
    required this.onSelect,
  });

  final NexusI18n i18n;
  final NexusSection current;
  final ValueChanged<NexusSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: i18n.t('shell.nav.label'),
      child: Container(
        decoration: const BoxDecoration(
          color: RdColors.rail,
          border: Border(top: BorderSide(color: RdColors.white8)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        // The tab InkWells need a Material ancestor for their ink.
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                for (final section in NexusSection.values)
                  Expanded(
                    child: _TabButton(
                      key: Key('tab-${section.name}'),
                      icon: section.icon,
                      label: i18n.t(section.tabLabelKey),
                      selected: section == current,
                      onTap: () => onSelect(section),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? RdColors.accent : RdColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
