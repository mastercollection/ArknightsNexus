import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'home_operator_highlights.dart';
import 'home_plan_summary.dart';
import 'home_region_sync.dart';
import '../shared/region_select.dart';

/// Home dashboard (port of `src/pages/index.vue`, redesigned after
/// `PcHome.dc.html` / `MHome.dc.html`). There are no shortcut tiles: the
/// shell's navigation already lists every section.
///
/// - expanded: the shell draws the sidebar (region / status / settings live
///   in its bottom block, [HomeSidebarPanel]); this page is the main column:
///   search, data card + plan summary, new releases, unreleased preview.
/// - medium: icon rail only, so the data card also carries the region
///   select, and the cards stack when the column is narrow.
/// - compact: brand + sync + region header, then one scrolling column with
///   the status line, search, plan summary and the two operator scrollers.
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
          : _buildWide(context, medium: layout == RdLayout.medium),
    );
  }

  Widget _buildCompact(BuildContext context, NexusI18n i18n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: RdColors.surface1,
            border: Border(bottom: BorderSide(color: RdColors.hairline)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeSyncStatusLine(showTime: true),
                const SizedBox(height: 16),
                _SearchBlock(
                  controller: _searchController,
                  compact: true,
                  onSubmit: _openOperatorSearch,
                ),
                const SizedBox(height: 16),
                const HomePlanSummaryCard(compact: true),
                const _Gap(HomeNewReleasesSection(compact: true)),
                const _Gap(HomeUnreleasedPreviewSection(compact: true)),
                const SizedBox(height: 20),
                const _RightsNotice(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context, {required bool medium}) {
    final padding = rdPagePadding(context);
    return SafeArea(
      left: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            // The rights notice sits at the bottom of a short page.
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - padding.vertical),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchBlock(
                      controller: _searchController,
                      compact: false,
                      onSubmit: _openOperatorSearch,
                    ),
                    const SizedBox(height: 20),
                    _DataAndPlanRow(medium: medium),
                    const _Gap(
                      HomeNewReleasesSection(compact: false),
                      gap: 20,
                    ),
                    const _Gap(
                      HomeUnreleasedPreviewSection(compact: false),
                      gap: 20,
                    ),
                  ],
                ),
                const _Gap(_RightsNotice(), gap: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] with [gap] above it.
class _Gap extends StatelessWidget {
  const _Gap(this.child, {this.gap = 16});

  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(top: gap), child: child);
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
        child: const Row(
          children: [
            RdAppMark(size: 28),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Arknights Nexus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
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

/// Quick search (`role="search"`): Enter in the field opens the operator
/// list (with `?q=` when there is a keyword); PC also has a search button.
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
      height: compact ? 48 : 44,
      onSubmitted: (_) => onSubmit(),
    );
    return Semantics(
      container: true,
      label: i18n.t('home.search.action'),
      child: compact
          ? field
          : Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 10),
                RdButton(
                  key: const Key('home-search-button'),
                  label: i18n.t('rd.home.searchButton'),
                  variant: RdButtonVariant.primary,
                  height: 44,
                  onPressed: onSubmit,
                ),
              ],
            ),
    );
  }
}

/// Data card (360px) next to the plan summary; stacked when the column is
/// too narrow for both.
class _DataAndPlanRow extends StatelessWidget {
  const _DataAndPlanRow({required this.medium});

  final bool medium;

  @override
  Widget build(BuildContext context) {
    final data = HomeDataCard(showRegionSelect: medium);
    const plan = HomePlanSummaryCard(compact: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360 + 20 + 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [data, const SizedBox(height: 20), plan],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 360, child: data),
            const SizedBox(width: 20),
            const Expanded(child: plan),
          ],
        );
      },
    );
  }
}

/// Rights notice: one small paragraph at the bottom of the page.
class _RightsNotice extends ConsumerWidget {
  const _RightsNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    return Text(
      i18n.t('home.notice.body'),
      key: const Key('home-rights-notice'),
      style: const TextStyle(fontSize: 12, height: 1.6, color: RdColors.text3),
    );
  }
}
