import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'home_plan_summary.dart';
import 'home_region_sync.dart';

const _appIcon = 'assets/icons/app/nexus-beacon.svg';

/// Home dashboard (port of `src/pages/index.vue`, redesigned after
/// `Main.dc.html` / `MobileHome.dc.html`).
///
/// - expanded: the shell draws the sidebar (region / sync / settings live in
///   its bottom block, [HomeSidebarPanel]); this page is the main column.
/// - medium: icon rail only, so the region select and sync sit above the
///   header.
/// - compact: brand + sync + region header, then one scrolling column.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = 'home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  GoRouter? _router;
  bool _wasOnHome = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router?.routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Pages pushed from home (plan, operator detail) can change the plan while
  /// home stays mounted underneath; recompute the summary when home is the
  /// visible page again so its numbers are never stale.
  void _onRouteChanged() {
    final router = _router;
    if (router == null || !mounted) {
      return;
    }
    final onHome = router.routerDelegate.currentConfiguration.uri.path == '/';
    if (onHome && !_wasOnHome) {
      ref.invalidate(homePlanSummaryProvider);
    }
    _wasOnHome = onHome;
  }

  /// `openOperatorSearch`: Enter and the button both open the operator list,
  /// with `?q=` only when there is a keyword.
  void _openOperatorSearch() {
    final query = _searchController.text.trim();
    context.push(
      query.isEmpty
          ? '/operators'
          : Uri(path: '/operators', queryParameters: {'q': query}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final layout = context.rdLayout;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: layout == RdLayout.compact
          ? _buildCompact(context, i18n)
          : _buildWide(context, i18n, medium: layout == RdLayout.medium),
    );
  }

  Widget _buildCompact(BuildContext context, NexusI18n i18n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Expanded(child: _Brand(onTap: () => context.go('/'))),
                const SizedBox(width: 8),
                const HomeSyncIconButton(),
                const SizedBox(width: 8),
                RdRegionSelect(
                  semanticLabel: i18n.t('rd.home.region.short'),
                  codesOnly: true,
                  height: 44,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeSyncStatusLine(withRegion: true, fontSize: 12),
                const SizedBox(height: 16),
                _SearchBlock(
                  controller: _searchController,
                  compact: true,
                  onSubmit: _openOperatorSearch,
                ),
                const SizedBox(height: 16),
                const HomePlanSummaryCard(compact: true),
                const SizedBox(height: 16),
                const _MenuGrid(compact: true),
                const SizedBox(height: 16),
                const _RightsNotice(compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWide(
    BuildContext context,
    NexusI18n i18n, {
    required bool medium,
  }) {
    return SafeArea(
      left: false,
      child: SingleChildScrollView(
        padding: rdPagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (medium) ...[
              Row(
                children: [
                  const Expanded(child: HomeSyncStatusLine(withRegion: true)),
                  const SizedBox(width: 8),
                  const HomeSyncButton(),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 168,
                    child: RdRegionSelect(
                      semanticLabel: i18n.t('rd.home.region.label'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n.t('rd.home.eyebrow'), style: RdText.eyebrow),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        i18n.t('rd.home.headline'),
                        style: RdText.pageTitle.copyWith(fontSize: 28),
                      ),
                    ),
                  ],
                );
                final search = _SearchBlock(
                  controller: _searchController,
                  compact: false,
                  onSubmit: _openOperatorSearch,
                );
                // flex: 1 1 280px | flex: 2 1 360px, wrapping when narrow.
                if (constraints.maxWidth < 280 + 16 + 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, const SizedBox(height: 16), search],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: search),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            // Without the sidebar (medium) the icon rail has no labels, so
            // the shortcuts lead the page, in one row, right under the search.
            if (medium) ...[
              const _MenuGrid(compact: false, minTileWidth: 150),
              const SizedBox(height: 28),
              const _WidePlanSection(),
            ] else ...[
              const _WidePlanSection(),
              const SizedBox(height: 28),
              const _MenuGrid(compact: false),
            ],
            const SizedBox(height: 28),
            const _RightsNotice(compact: false),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(RdRadii.small),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1730),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x598BD6FF)),
              ),
              child: SvgPicture.asset(_appIcon),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Arknights Nexus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// Quick search (`role="search"`): the field submits on Enter, the button
/// does the same, and the hint says where it leads.
class _SearchBlock extends ConsumerWidget {
  const _SearchBlock({
    required this.controller,
    required this.compact,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool compact;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final field = RdSearchField(
      key: const Key('home-search-field'),
      controller: controller,
      hintText: i18n.t('home.search.placeholder'),
      height: 48,
      onSubmitted: (_) => onSubmit(),
      trailing: compact ? null : const _EnterKey(),
    );
    return Semantics(
      container: true,
      label: i18n.t('home.search.eyebrow'),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final query = value.text.trim();
          final hint = Text(
            query.isEmpty
                ? i18n.t('rd.home.searchHint')
                : i18n.t('rd.home.searchHintQuery', {'query': query}),
            style: RdText.small,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 8),
                _TonalButton(
                  key: const Key('home-search-button'),
                  label: query.isEmpty
                      ? i18n.t('home.search.action')
                      : i18n.t('rd.home.searchWithQuery', {'query': query}),
                  onPressed: onSubmit,
                ),
                const SizedBox(height: 8),
                hint,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 8),
                  RdButton(
                    key: const Key('home-search-button'),
                    label: i18n.t('home.search.action'),
                    variant: RdButtonVariant.primary,
                    height: 48,
                    onPressed: onSubmit,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              hint,
            ],
          );
        },
      ),
    );
  }
}

class _EnterKey extends StatelessWidget {
  const _EnterKey();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: RdColors.white14),
        ),
        child: Text(
          'Enter',
          style: RdText.mono(fontSize: 11, color: RdColors.muted),
        ),
      ),
    );
  }
}

/// Full-width accent-tinted button of the phone layouts.
class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: RdColors.tonalFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.control),
          side: const BorderSide(color: RdColors.tonalBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.control),
          onTap: onPressed,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Summary card (flex 2) next to the planned operators (flex 1); the second
/// card only exists when the plan has operators.
class _WidePlanSection extends ConsumerWidget {
  const _WidePlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homePlanSummaryProvider).valueOrNull;
    const card = HomePlanSummaryCard(compact: false);
    if (summary == null || summary.isEmpty) {
      return card;
    }
    final planned = HomePlannedOperatorsCard(summary: summary);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 + 16 + 260) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [card, const SizedBox(height: 16), planned],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 2, child: card),
            const SizedBox(width: 16),
            Expanded(child: planned),
          ],
        );
      },
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.caption,
    required this.status,
    required this.icon,
    required this.id,
    this.route,
  });

  final String id;
  final String title;
  final String caption;
  final String status;
  final String icon;
  final String? route;

  bool get enabled => route != null;
}

/// Menu tiles of `index.vue` (Operators / Plan / Items active, Enemies
/// "pending" and inert).
class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({required this.compact, this.minTileWidth = 220});

  final bool compact;

  /// `minmax(<this>, 1fr)` of the PC grid.
  final double minTileWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final items = [
      _MenuItem(
        id: 'operators',
        title: 'Operators',
        caption: i18n.t('home.menu.operators.caption'),
        status: i18n.t('home.menu.status.active'),
        icon: 'assets/icons/home/operator.webp',
        route: '/operators',
      ),
      _MenuItem(
        id: 'plan',
        title: 'Plan',
        caption: i18n.t('home.menu.plan.caption'),
        status: i18n.t('home.menu.status.active'),
        icon: 'assets/icons/home/prts.png',
        route: '/plan',
      ),
      _MenuItem(
        id: 'items',
        title: 'Items',
        caption: i18n.t('home.menu.items.caption'),
        status: i18n.t('home.menu.status.active'),
        icon: 'assets/icons/home/items.webp',
        route: '/items',
      ),
      _MenuItem(
        id: 'enemies',
        title: 'Enemies',
        caption: i18n.t('home.menu.enemies.caption'),
        status: i18n.t('home.menu.status.pending'),
        icon: 'assets/icons/home/enemy.webp',
      ),
    ];
    // repeat(auto-fit, minmax(220px, 1fr)) on PC, two columns on phones.
    final grid = RdAutoGrid(
      columns: compact ? 2 : null,
      minTileWidth: minTileWidth,
      maxColumns: 4,
      gap: compact ? 12.0 : 14.0,
      equalHeight: true,
      children: [
        for (final item in items) _MenuTile(item: item, compact: compact),
      ],
    );
    if (compact) {
      return grid;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(i18n.t('rd.home.shortcuts'), style: RdText.sectionTitle),
        ),
        const SizedBox(height: 14),
        grid,
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.compact});

  final _MenuItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: RdColors.portrait,
                borderRadius: BorderRadius.circular(RdRadii.control),
              ),
              child: Image.asset(item.icon, fit: BoxFit.contain),
            ),
            const Spacer(),
            RdPill(label: item.status, fontSize: compact ? 11 : 12),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          item.title,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
            color: RdColors.text,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          item.caption,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            height: 1.5,
            color: RdColors.muted,
          ),
        ),
      ],
    );
    final tile = Material(
      color: RdColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RdRadii.tile),
        side: const BorderSide(color: RdColors.line2),
      ),
      child: InkWell(
        key: Key('home-menu-${item.id}'),
        borderRadius: BorderRadius.circular(RdRadii.tile),
        onTap: item.enabled ? () => context.push(item.route!) : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 0 : 150),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 18),
            child: content,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: item.enabled,
      child: item.enabled ? tile : Opacity(opacity: 0.55, child: tile),
    );
  }
}

/// "권리 안내" footer.
class _RightsNotice extends ConsumerWidget {
  const _RightsNotice({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    return Container(
      padding: compact
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: RdColors.rail,
        borderRadius: BorderRadius.circular(16),
        border: compact ? Border.all(color: RdColors.line) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('home.notice.eyebrow'),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: RdColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            i18n.t('home.notice.title'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: compact ? RdColors.text : RdColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            i18n.t('home.notice.body'),
            style: const TextStyle(
              fontSize: 13,
              height: 1.7,
              color: RdColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
