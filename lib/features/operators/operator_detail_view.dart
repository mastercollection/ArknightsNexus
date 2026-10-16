import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data_sources/image_source.dart';
import '../../data_sources/region_code.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/image_cache_service.dart';
import '../../services/rich_description.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import '../../widgets/resolved_image_provider.dart';
import 'operator_detail_panels.dart';
import 'operator_detail_view_model.dart';
import 'operator_detail_widgets.dart';
import 'operators_common.dart';

/// Detail sections, shown as tabs (they were collapsible panels on one long
/// page before the redesign).
enum DetailSection { stats, abilities, potentials, modules, skills }

/// Where the detail is rendered.
enum OperatorDetailMode {
  /// Full page (phone / tablet): header bar, sticky tabs, bottom action bar.
  page,

  /// Right-hand pane of the PC master-detail workspace.
  pane,
}

/// Port of `src/pages/operators/[operatorId].vue`.
///
/// Loads the operator, its BA terms, favorite and plan state; keeps the
/// elite/level, ability tab, skill and section selection; persists the
/// favorite with a 250ms debounce (`useAutoPersist`) and adds the operator to
/// the plan.
class OperatorDetailView extends ConsumerStatefulWidget {
  const OperatorDetailView({
    required this.operatorId,
    required this.mode,
    required this.onBack,
    super.key,
  });

  final String operatorId;
  final OperatorDetailMode mode;

  /// Header back button (page: pop or return to the list; pane: deselect).
  final VoidCallback onBack;

  @override
  ConsumerState<OperatorDetailView> createState() => _OperatorDetailViewState();
}

class _OperatorDetailViewState extends ConsumerState<OperatorDetailView> {
  OperatorDetail? _operator;
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, String> _terms = const {};
  Map<String, ImageProvider> _skillIcons = const {};
  Map<String, ImageProvider> _moduleTypeIcons = const {};
  Map<String, ImageProvider> _moduleEquipIcons = const {};
  int _loadToken = 0;

  // Favorite auto-persist (`useAutoPersist`, 250ms debounce).
  bool _isFavorite = false;
  bool _persistedFavorite = false;
  bool _persisting = false;
  bool _pendingPersist = false;
  Timer? _persistTimer;

  // Plan membership.
  bool _inPlan = false;
  bool _addingToPlan = false;

  int _elite = 0;
  int _level = 1;
  int _abilitiesEliteTab = 0;
  String? _selectedSkillId;
  int _selectedSkillLevel = 1;
  DetailSection _section = DetailSection.stats;

  final _scrollController = ScrollController();

  ProviderSubscription<RegionCode>? _regionSub;
  ProviderSubscription<int>? _revisionSub;

  bool get _compact => widget.mode == OperatorDetailMode.page;

  @override
  void initState() {
    super.initState();
    _regionSub = ref.listenManual(regionProvider, (_, __) => _load());
    _revisionSub = ref.listenManual(dataRevisionProvider, (_, __) => _load());
    _load();
  }

  @override
  void didUpdateWidget(OperatorDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operatorId != widget.operatorId) {
      // Selecting another operator (PC list) keeps the elite and section,
      // like the canvas, but resets skill/module picks and scrolls to top.
      _persistTimer?.cancel();
      _selectedSkillId = null;
      _selectedSkillLevel = 1;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _load();
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _regionSub?.close();
    _revisionSub?.close();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  Future<void> _load() async {
    final token = ++_loadToken;
    final region = ref.read(regionProvider);
    final operatorId = widget.operatorId;
    final stale = _operator != null && _operator!.id != operatorId;
    if (!_isLoading || _errorMessage.isNotEmpty || stale) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        if (stale) {
          _operator = null;
        }
      });
    }

    try {
      final operator = await ref
          .read(operatorServiceProvider)
          .getOperatorDetail(region, operatorId);
      final terms =
          await ref.read(regionSyncServiceProvider).getRegionTerms(region);
      final userData = ref.read(userDataServiceProvider);
      final favorites = await userData.getFavorites();
      var inPlan = false;
      try {
        final plan = await userData.getUserPlan();
        inPlan = plan.selectedOperatorIds.contains(operatorId);
      } catch (_) {
        // The add button stays available; adding reports its own failure.
      }

      final images = ref.read(imageCacheServiceProvider);
      var skillIcons = <String, ImageProvider>{};
      var typeIcons = <String, ImageProvider>{};
      var equipIcons = <String, ImageProvider>{};
      if (operator != null) {
        try {
          await images.prefetch([
            ImageRequest(kind: CachedImageKind.portrait, id: operator.id),
          ]);
        } catch (_) {
          // The portrait widget has its own fallback.
        }
        skillIcons = await _resolveAll(images, {
          for (final skill in operator.skills)
            skill.id: (
              CachedImageKind.skillIcon,
              (skill.iconId ?? skill.id).trim()
            ),
        });
        typeIcons = await _resolveAll(images, {
          for (final module in operator.modules)
            module.uniEquipId: (
              CachedImageKind.moduleType,
              module.typeIcon.trim()
            ),
        });
        equipIcons = await _resolveAll(images, {
          for (final module in operator.modules)
            module.uniEquipId: (
              CachedImageKind.moduleEquip,
              _moduleEquipRequestId(module) ?? '',
            ),
        });
      }

      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _operator = operator;
        _terms = terms;
        _skillIcons = skillIcons;
        _moduleTypeIcons = typeIcons;
        _moduleEquipIcons = equipIcons;
        _isFavorite = favorites.contains(operatorId);
        _persistedFavorite = _isFavorite;
        _persistTimer?.cancel();
        _inPlan = inPlan;
        _abilitiesEliteTab = _elite;
        _normalizeSelection();
      });
    } catch (error) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _operator = null;
        _errorMessage = '$error';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, ImageProvider>> _resolveAll(
    ImageCacheService images,
    Map<String, (CachedImageKind, String)> requests,
  ) async {
    final valid = {
      for (final entry in requests.entries)
        if (entry.value.$2.isNotEmpty) entry.key: entry.value,
    };
    try {
      await images.prefetch([
        for (final request in valid.values)
          ImageRequest(kind: request.$1, id: request.$2),
      ]);
    } catch (_) {
      // Fallback UI covers missing images.
    }
    final resolved = <String, ImageProvider>{};
    await Future.wait(
      valid.entries.map((entry) async {
        try {
          final image = await images.resolve(
            ImageRequest(kind: entry.value.$1, id: entry.value.$2),
          );
          final provider = resolvedImageProvider(image);
          if (provider != null) {
            resolved[entry.key] = provider;
          }
        } catch (_) {
          // Ignore individual failures.
        }
      }),
    );
    return resolved;
  }

  String? _moduleEquipRequestId(OperatorModule module) {
    final icon = module.uniEquipIcon.trim();
    if (icon.isEmpty) {
      return null;
    }
    if (module.typeIcon.trim().toLowerCase() == 'original') {
      return 'original';
    }
    return icon;
  }

  /// The page's `watchEffect` guards.
  void _normalizeSelection() {
    final operator = _operator;
    if (operator == null) {
      return;
    }
    if (_elite >= operator.eliteCaps.length ||
        operator.eliteCaps[_elite] == 0) {
      _elite = 0;
    }
    if (_abilitiesEliteTab >= operator.eliteCaps.length) {
      _abilitiesEliteTab = 0;
    }
    final maxLevel = _maxLevel(operator);
    if (_level > maxLevel) {
      _level = maxLevel;
    }
    if (_level < 1) {
      _level = 1;
    }
    _selectedSkillId ??=
        operator.skills.isEmpty ? null : operator.skills.first.id;
    final levels = _selectedSkill(operator)?.levels.length ?? 1;
    if (_selectedSkillLevel > levels) {
      _selectedSkillLevel = levels;
    }
    if (!_sections(operator).contains(_section)) {
      _section = DetailSection.stats;
    }
  }

  int _maxLevel(OperatorDetail operator) {
    return _elite < operator.eliteCaps.length ? operator.eliteCaps[_elite] : 1;
  }

  OperatorSkill? _selectedSkill(OperatorDetail operator) {
    for (final skill in operator.skills) {
      if (skill.id == _selectedSkillId) {
        return skill;
      }
    }
    return operator.skills.isEmpty ? null : operator.skills.first;
  }

  /// Potentials / modules only exist when the operator has them (`v-if`).
  List<DetailSection> _sections(OperatorDetail operator) {
    return [
      DetailSection.stats,
      DetailSection.abilities,
      if (operator.potentials.isNotEmpty) DetailSection.potentials,
      if (operator.modules.isNotEmpty) DetailSection.modules,
      DetailSection.skills,
    ];
  }

  // -------------------------------------------------------------------------
  // Favorite
  // -------------------------------------------------------------------------

  void _toggleFavorite() {
    if (_operator == null) {
      return;
    }
    setState(() => _isFavorite = !_isFavorite);
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), _persistFavorite);
  }

  Future<void> _persistFavorite() async {
    final operator = _operator;
    if (operator == null || _isFavorite == _persistedFavorite) {
      return;
    }
    if (_persisting) {
      _pendingPersist = true;
      return;
    }
    _persisting = true;
    final desired = _isFavorite;
    final service = ref.read(userDataServiceProvider);
    try {
      var persisted = await service.toggleOperatorFavorite(operator.id);
      if (persisted != desired) {
        persisted = await service.toggleOperatorFavorite(operator.id);
      }
      _persistedFavorite = persisted;
      if (mounted && !_pendingPersist) {
        setState(() => _isFavorite = persisted);
      }
    } catch (_) {
      if (mounted) {
        // `ElMessage.info(favoriteFailed)`.
        showNexusMessage(
          context,
          ref.read(i18nProvider).t('operatorDetail.messages.favoriteFailed'),
        );
      }
    } finally {
      _persisting = false;
      if (_pendingPersist) {
        _pendingPersist = false;
        if (_isFavorite != _persistedFavorite) {
          _persistTimer?.cancel();
          _persistTimer =
              Timer(const Duration(milliseconds: 250), _persistFavorite);
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Plan
  // -------------------------------------------------------------------------

  /// `saveUserPlanSelection([...ids, id])`; already-added operators are a
  /// no-op (the button is disabled).
  Future<void> _addToPlan() async {
    final operator = _operator;
    if (operator == null || _inPlan || _addingToPlan) {
      return;
    }
    final i18n = ref.read(i18nProvider);
    setState(() => _addingToPlan = true);
    final service = ref.read(userDataServiceProvider);
    try {
      final plan = await service.getUserPlan();
      final ids = await service.saveUserPlanSelection([
        ...plan.selectedOperatorIds,
        if (!plan.selectedOperatorIds.contains(operator.id)) operator.id,
      ]);
      if (!mounted) {
        return;
      }
      setState(() => _inPlan = ids.contains(operator.id));
      showNexusMessage(
        context,
        i18n.t('rd.operators.detail.added'),
        type: NexusMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        showNexusMessage(
          context,
          '${i18n.t('rd.operators.detail.addFailed')} $error',
          type: NexusMessageType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingToPlan = false);
      }
    }
  }

  void _openPlan() {
    final operator = _operator;
    if (operator != null) {
      context.push('/plan/${operator.id}');
    }
  }

  // -------------------------------------------------------------------------
  // Term sheet
  // -------------------------------------------------------------------------

  void _openTerm(String key, String label) {
    final description = _terms[key];
    if (description == null || description.isEmpty) {
      return;
    }
    showOperatorTermSheet(
      context: context,
      terms: _terms,
      termKey: key,
      label: label,
      i18n: ref.read(i18nProvider),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final operator = _operator;

    if (operator == null) {
      return _buildState(i18n);
    }

    final sections = _sections(operator);
    final section = sections.contains(_section) ? _section : sections.first;
    final favoriteButton = _FavoriteButton(
      favorite: _isFavorite,
      tooltip: i18n.t('rd.operators.detail.favorite'),
      size: _compact ? 44 : 36,
      onPressed: _toggleFavorite,
    );
    final hero = _HeroCard(
      operator: operator,
      i18n: i18n,
      compact: _compact,
      // Phones keep the favorite in the app bar; the pane has no bar, so
      // its hero carries the favorite and the button closing the pane.
      trailing: _compact
          ? null
          : [
              favoriteButton,
              RdIconButton(
                icon: Icons.close,
                tooltip: i18n.t('common.close'),
                onPressed: widget.onBack,
                size: 36,
                iconSize: 18,
              ),
            ],
    );
    final tabs = _DetailTabs(
      key: const ValueKey('detail-tabs'),
      semanticLabel: i18n.t('rd.operators.detail.sections'),
      selected: section,
      sections: [
        for (final entry in sections)
          (entry, i18n.t('operatorDetail.sections.${entry.name}')),
      ],
      onChanged: (value) => setState(() => _section = value),
    );
    final panel = KeyedSubtree(
      key: ValueKey('panel-${section.name}'),
      child: _buildPanel(operator, section, i18n),
    );
    final actions = _PlanActions(
      inPlan: _inPlan,
      busy: _addingToPlan,
      compact: _compact,
      i18n: i18n,
      onAdd: _addToPlan,
      onOpen: _openPlan,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones and the pane use their whole width; a tablet page centres
        // an 860px column.
        final side =
            _compact ? math.max(16.0, (constraints.maxWidth - 860) / 2) : 20.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_compact)
              _PageBar(
                name: operator.name,
                backTooltip: i18n.t('common.back'),
                onBack: widget.onBack,
                favorite: favoriteButton,
              ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(side, _compact ? 14 : 20, side, 0),
                    sliver: SliverToBoxAdapter(child: hero),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabsDelegate(
                      background: _compact ? RdColors.bg : RdColors.surface1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: side),
                        child: tabs,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, 14, side, 24),
                    sliver: SliverToBoxAdapter(child: panel),
                  ),
                ],
              ),
            ),
            // Sticky plan actions under the scrolling detail.
            Container(
              padding: _compact
                  ? EdgeInsets.fromLTRB(side, 10, side, 10)
                  : const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: RdColors.surface1,
                border: Border(top: BorderSide(color: RdColors.border)),
              ),
              child: SafeArea(top: false, child: actions),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel(
    OperatorDetail operator,
    DetailSection section,
    NexusI18n i18n,
  ) {
    switch (section) {
      case DetailSection.stats:
        return OperatorStatsPanel(
          operator: operator,
          i18n: i18n,
          elite: _elite,
          level: _level,
          compact: _compact,
          onEliteChanged: (value) => setState(() {
            _elite = value;
            _level = math.min(_level, _maxLevel(operator));
            _normalizeSelection();
          }),
          onLevelChanged: (value) => setState(() => _level = value),
        );
      case DetailSection.abilities:
        return OperatorAbilitiesPanel(
          operator: operator,
          i18n: i18n,
          eliteTab: _abilitiesEliteTab,
          compact: _compact,
          onEliteTabChanged: (value) =>
              setState(() => _abilitiesEliteTab = value),
          onTermTap: _openTerm,
        );
      case DetailSection.potentials:
        return OperatorPotentialsPanel(
          potentials: buildPotentials(operator, i18n),
        );
      case DetailSection.modules:
        return OperatorModulesPanel(
          operator: operator,
          i18n: i18n,
          typeIcons: _moduleTypeIcons,
          equipIcons: _moduleEquipIcons,
          onTermTap: _openTerm,
          compact: _compact,
        );
      case DetailSection.skills:
        return OperatorSkillsPanel(
          operator: operator,
          i18n: i18n,
          selectedSkill: _selectedSkill(operator),
          selectedLevel: _selectedSkillLevel,
          skillIcons: _skillIcons,
          compact: _compact,
          onSkillSelected: (id) => setState(() {
            if (id != _selectedSkillId) {
              _selectedSkillId = id;
              _selectedSkillLevel = 1;
            }
          }),
          onLevelChanged: (value) =>
              setState(() => _selectedSkillLevel = value),
          onTermTap: _openTerm,
        );
    }
  }

  Widget _buildState(NexusI18n i18n) {
    final String title;
    final String message;
    Widget? action;
    final RdStateKind kind;
    if (_isLoading) {
      kind = RdStateKind.loading;
      title = i18n.t('operatorDetail.states.loadingTitle');
      message = i18n.t('operatorDetail.states.loadingDescription');
    } else if (_errorMessage.isNotEmpty) {
      kind = RdStateKind.error;
      title = i18n.t('operatorDetail.states.errorTitle');
      message = _errorMessage;
    } else {
      kind = RdStateKind.empty;
      title = i18n.t('operatorDetail.states.notFoundTitle');
      message = i18n.t('operatorDetail.states.notFoundDescription');
      action = SizedBox(
        height: _compact ? 48 : 44,
        child: FilledButton(
          key: const Key('operator-detail-back-to-list'),
          style: FilledButton.styleFrom(
            backgroundColor: RdColors.accent,
            foregroundColor: RdColors.onAccent,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            textStyle: TextStyle(
              fontSize: _compact ? 15 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => context.go('/operators'),
          child: Text(i18n.t('operatorDetail.states.backToList')),
        ),
      );
    }

    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            liveRegion: kind != RdStateKind.empty,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == RdStateKind.loading) ...[
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: RdColors.accent,
                      backgroundColor: RdColors.accentSoft,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: RdColors.muted,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
            ),
          ),
        ),
      ),
    );
    if (!_compact) {
      return body;
    }
    // Keep a back button on phones so the page is never a dead end.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: const BoxDecoration(
            color: RdColors.header,
            border: Border(bottom: BorderSide(color: RdColors.line)),
          ),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: RdIconButton(
                icon: Icons.chevron_left,
                tooltip: i18n.t('common.back'),
                onPressed: widget.onBack,
                size: 44,
                iconSize: 22,
                iconColor: RdColors.text,
              ),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabsDelegate({required this.child, required this.background});

  final Widget child;

  /// The scroll view's background, so pinned tabs hide what scrolls under.
  final Color background;

  static const _height = _DetailTabs.height + 8;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: background,
      child: Align(alignment: Alignment.bottomCenter, child: child),
    );
  }

  @override
  bool shouldRebuild(_StickyTabsDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.background != background;
}

// ---------------------------------------------------------------------------
// App bar / hero / tabs / actions
// ---------------------------------------------------------------------------

/// App bar of the detail page: back, the operator name, favorite.
class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.name,
    required this.backTooltip,
    required this.onBack,
    required this.favorite,
  });

  final String name;
  final String backTooltip;
  final VoidCallback onBack;
  final Widget favorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            RdIconButton(
              icon: Icons.chevron_left,
              tooltip: backTooltip,
              onPressed: onBack,
              filled: false,
              iconSize: 22,
              iconColor: RdColors.text,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RdText.mobileTitle,
              ),
            ),
            favorite,
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.favorite,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final bool favorite;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RdIconButton(
      icon: favorite ? Icons.star : Icons.star_border,
      tooltip: tooltip,
      onPressed: onPressed,
      size: size,
      toggled: favorite,
      iconSize: 20,
      iconColor: RdColors.rarity,
    );
  }
}

/// Underlined section tabs right under the hero.
class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.sections,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  static const height = 42.0;

  final List<(DetailSection, String)> sections;
  final DetailSection selected;
  final ValueChanged<DetailSection> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: RdColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (section, label) in sections)
              Expanded(
                child: _DetailTab(
                  label: label,
                  selected: section == selected,
                  onTap: () => onChanged(section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? RdColors.accent : Colors.transparent,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? RdColors.text : RdColors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal hero: portrait on the left; name (with the
/// unreleased badge), rarity and chips on the right; the quote on one line
/// and the base / term tags below.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.operator,
    required this.i18n,
    required this.compact,
    this.trailing,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final bool compact;

  /// Buttons at the end of the name row (pane: favorite and close).
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final source = operator.unreleasedSource;
    final name = Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            operator.name,
            style: compact ? RdText.mobileTitle : RdText.pageTitle,
          ),
        ),
        // Never truncated: it wraps under a long name instead.
        if (source != null)
          UnreleasedBadge(
            key: const Key('operator-detail-unreleased'),
            label: unreleasedLabel(i18n, source),
            tooltip: unreleasedDescription(i18n, source),
          ),
      ],
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: name,
              ),
            ),
            if (trailing != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: trailing!,
              ),
          ],
        ),
        Text(
          '★' * operator.rarity,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            height: 1,
            letterSpacing: 0.4,
            color: RdColors.rarity,
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final team in operator.teams)
              OpChip.text(team, kind: OpChipKind.team),
            for (final nation in operator.nations)
              OpChip.text(nation, kind: OpChipKind.nation),
            for (final group in operator.groups)
              OpChip.text(group, kind: OpChipKind.group),
            OpChip.text(
              i18n.profession(operator.profession),
              kind: OpChipKind.prof,
            ),
            OpChip.text(operator.branch, kind: OpChipKind.branch),
          ],
        ),
      ],
    );
    final tags = [
      if (operator.tags.isNotEmpty)
        Semantics(
          container: true,
          label: i18n.t('operatorDetail.labels.baseTags'),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final tag in operator.tags) OpChip.text(tag)],
          ),
        ),
      if (operator.baTags.isNotEmpty)
        Semantics(
          container: true,
          label: i18n.t('operatorDetail.labels.termTags'),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in operator.baTags)
                OpChip.text(tag, kind: OpChipKind.ba),
            ],
          ),
        ),
    ];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RdPortrait(
              charId: operator.id,
              name: operator.name,
              size: compact ? 104 : 112,
              radius: 12,
            ),
            SizedBox(width: compact ? 14 : 16),
            Expanded(child: info),
          ],
        ),
        if (operator.quote.isNotEmpty) _QuoteLine(operator.quote),
        ...tags,
      ],
    );
    if (compact) {
      return content;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RdColors.surface2,
        borderRadius: BorderRadius.circular(RdRadii.card),
        border: Border.all(color: RdColors.hairline),
      ),
      child: content,
    );
  }
}

/// The operator's quote on one line; a tap shows the whole quote.
class _QuoteLine extends StatefulWidget {
  const _QuoteLine(this.quote);

  final String quote;

  @override
  State<_QuoteLine> createState() => _QuoteLineState();
}

class _QuoteLineState extends State<_QuoteLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Text(
        widget.quote,
        maxLines: _expanded ? null : 1,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: RdColors.text2,
        ),
      ),
    );
  }
}

class _PlanActions extends StatelessWidget {
  const _PlanActions({
    required this.inPlan,
    required this.busy,
    required this.compact,
    required this.i18n,
    required this.onAdd,
    required this.onOpen,
  });

  final bool inPlan;
  final bool busy;
  final bool compact;
  final NexusI18n i18n;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 48.0 : 44.0;
    final add = inPlan
        ? Semantics(
            button: true,
            enabled: false,
            child: Container(
              key: const Key('operator-detail-in-plan'),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RdColors.successFill,
                borderRadius: BorderRadius.circular(RdRadii.control),
                border: Border.all(color: RdColors.success),
              ),
              child: Text(
                i18n.t('rd.operators.detail.inPlan'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: RdColors.success,
                ),
              ),
            ),
          )
        : RdButton(
            key: const Key('operator-detail-add-to-plan'),
            label: i18n.t('rd.operators.detail.addToPlan'),
            variant: RdButtonVariant.primary,
            height: height,
            expand: true,
            busy: busy,
            onPressed: onAdd,
          );
    final open = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RdRadii.control),
        side: const BorderSide(color: RdColors.border),
      ),
      child: InkWell(
        key: const Key('operator-detail-open-plan'),
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: onOpen,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            i18n.t('common.openPlan'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: RdColors.text,
            ),
          ),
        ),
      ),
    );
    return Row(
      spacing: 8,
      children: [Expanded(child: add), open],
    );
  }
}

// ---------------------------------------------------------------------------
// Term sheet
// ---------------------------------------------------------------------------

/// BA term explanation: a bottom sheet on phones, a dialog near the top on
/// wider layouts. Terms inside the description open in place.
Future<void> showOperatorTermSheet({
  required BuildContext context,
  required Map<String, String> terms,
  required String termKey,
  required String label,
  required NexusI18n i18n,
}) {
  final compact = context.rdLayout == RdLayout.compact;
  final content = _TermContent(
    terms: terms,
    initialKey: termKey,
    initialLabel: label,
    i18n: i18n,
    compact: compact,
  );
  final height = MediaQuery.sizeOf(context).height;
  return showRdSheet<void>(
    context: context,
    barrierLabel: i18n.t('common.close'),
    sheetMaxHeight: height * 0.65,
    dialogMaxHeight: height * 0.7,
    dialogAlignment: const Alignment(0, -0.6),
    dialogPadding: const EdgeInsets.all(24),
    builder: (context) => content,
  );
}

class _TermContent extends StatefulWidget {
  const _TermContent({
    required this.terms,
    required this.initialKey,
    required this.initialLabel,
    required this.i18n,
    required this.compact,
  });

  final Map<String, String> terms;
  final String initialKey;
  final String initialLabel;
  final NexusI18n i18n;
  final bool compact;

  @override
  State<_TermContent> createState() => _TermContentState();
}

class _TermContentState extends State<_TermContent> {
  late String _label = widget.initialLabel;
  late String _description = widget.terms[widget.initialKey] ?? '';

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final radius = compact
        ? const BorderRadius.vertical(top: Radius.circular(RdRadii.sheet))
        : BorderRadius.circular(RdRadii.sheet);
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: _label,
        explicitChildNodes: true,
        child: Container(
          key: const ValueKey('term-drawer'),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: compact
                ? const Border(top: BorderSide(color: RdColors.hairline))
                : Border.all(color: RdColors.hairline),
            color: RdColors.surface2,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  compact ? 12 : 18,
                  compact ? 16 : 20,
                  compact ? 28 : 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (compact) ...[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: RdColors.white20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                widget.i18n
                                    .t('operatorDetail.labels.termSheet'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.4,
                                  color: RdColors.muted,
                                ),
                              ),
                              Text(
                                _label,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: RdColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        RdIconButton(
                          icon: Icons.close,
                          tooltip: widget.i18n.t('common.close'),
                          size: compact ? 44 : 40,
                          filled: false,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 10),
                    RichTextContent(
                      segments: parseRichDescription(_description),
                      style: TextStyle(
                        fontSize: compact ? 15 : 14,
                        height: 1.75,
                        color: RdColors.body,
                      ),
                      onTermTap: (key, label) {
                        final next = widget.terms[key];
                        if (next == null || next.isEmpty) {
                          return;
                        }
                        setState(() {
                          _label = label;
                          _description = next;
                        });
                        SemanticsService.announce(
                          label,
                          Directionality.of(context),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
