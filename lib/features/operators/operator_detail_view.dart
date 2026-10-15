import 'dart:async';
import 'dart:io';
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
  Map<String, File> _skillIcons = const {};
  Map<String, File> _moduleTypeIcons = const {};
  Map<String, File> _moduleEquipIcons = const {};
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
      var skillIcons = <String, File>{};
      var typeIcons = <String, File>{};
      var equipIcons = <String, File>{};
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

  Future<Map<String, File>> _resolveAll(
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
    final resolved = <String, File>{};
    await Future.wait(
      valid.entries.map((entry) async {
        try {
          final image = await images.resolve(
            ImageRequest(kind: entry.value.$1, id: entry.value.$2),
          );
          if (image.isReady && image.file != null) {
            resolved[entry.key] = image.file!;
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
    final header = _DetailHeader(
      name: operator.name,
      sectionLabel: i18n.t('operatorDetail.sections.${section.name}'),
      favorite: _isFavorite,
      compact: _compact,
      backTooltip: i18n.t('rd.operators.back'),
      favoriteTooltip: i18n.t('rd.operators.detail.favorite'),
      onBack: widget.onBack,
      onToggleFavorite: _toggleFavorite,
    );
    final hero = _HeroCard(operator: operator, i18n: i18n, compact: _compact);
    final tabs = OpSegmented<DetailSection>(
      key: const ValueKey('detail-tabs'),
      semanticLabel: i18n.t('rd.operators.detail.sections'),
      height: _compact ? 44 : 40,
      value: section,
      segments: [
        for (final entry in sections)
          OpSegment(entry, i18n.t('operatorDetail.sections.${entry.name}')),
      ],
      onChanged: (value) => setState(() => _section = value),
    );
    final summary = Text(
      i18n.t('operatorDetail.summaries.${section.name}'),
      style: RdText.muted,
    );
    final panel = KeyedSubtree(
      key: ValueKey('panel-${section.name}'),
      child: _buildPanel(operator, section, i18n),
    );
    final actions = _PlanActions(
      inPlan: _inPlan,
      busy: _addingToPlan,
      favorite: _isFavorite,
      showFavorite: !_compact,
      i18n: i18n,
      onAdd: _addToPlan,
      onOpen: _openPlan,
      onToggleFavorite: _toggleFavorite,
    );

    if (!_compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: header,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 16),
                  tabs,
                  const SizedBox(height: 10),
                  summary,
                  const SizedBox(height: 16),
                  panel,
                  const SizedBox(height: 24),
                  actions,
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Page: centred column on tablets, sticky tabs, bottom action bar.
    return LayoutBuilder(
      builder: (context, constraints) => _buildPage(
        header: header,
        hero: hero,
        tabs: tabs,
        summary: summary,
        panel: panel,
        actions: actions,
        side: math.max(16.0, (constraints.maxWidth - 860) / 2),
      ),
    );
  }

  Widget _buildPage({
    required Widget header,
    required Widget hero,
    required Widget tabs,
    required Widget summary,
    required Widget panel,
    required Widget actions,
    required double side,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 12, side, 0),
                sliver: SliverToBoxAdapter(child: hero),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabsDelegate(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: tabs,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 2, side, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 14),
                      panel,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(side, 10, side, 12),
          decoration: const BoxDecoration(
            color: RdColors.rail,
            border: Border(top: BorderSide(color: RdColors.white8)),
          ),
          child: actions,
        ),
      ],
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
                      backgroundColor: Color(0x4085B6FF),
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
              child: _HeaderButton(
                tooltip: i18n.t('rd.operators.back'),
                size: 44,
                onPressed: widget.onBack,
                child: const Icon(
                  Icons.chevron_left,
                  size: 22,
                  color: Color(0xFFEBF0FF),
                ),
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
  const _StickyTabsDelegate({required this.child});

  final Widget child;

  static const _height = 44 + 8 + 20.0;

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
      color: RdColors.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabsDelegate oldDelegate) =>
      oldDelegate.child != child;
}

// ---------------------------------------------------------------------------
// Header / hero / actions
// ---------------------------------------------------------------------------

/// 14px-radius soft button of the detail header.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.size = 40,
    this.pressed,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;
  final double size;
  final bool? pressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        toggled: pressed,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: RdColors.white5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: RdColors.white8),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.name,
    required this.sectionLabel,
    required this.favorite,
    required this.compact,
    required this.backTooltip,
    required this.favoriteTooltip,
    required this.onBack,
    required this.onToggleFavorite,
  });

  final String name;
  final String sectionLabel;
  final bool favorite;
  final bool compact;
  final String backTooltip;
  final String favoriteTooltip;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 40.0;
    final row = Row(
      children: [
        _HeaderButton(
          tooltip: backTooltip,
          size: size,
          onPressed: onBack,
          child: const Icon(
            Icons.chevron_left,
            size: 22,
            color: Color(0xFFEBF0FF),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: RdColors.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x246890FF),
            borderRadius: BorderRadius.circular(RdRadii.pill),
          ),
          child: Text(
            sectionLabel,
            style: const TextStyle(fontSize: 12, color: Color(0xFFD8E5FF)),
          ),
        ),
        const Spacer(),
        _FavoriteButton(
          favorite: favorite,
          tooltip: favoriteTooltip,
          size: size,
          onPressed: onToggleFavorite,
        ),
      ],
    );
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: RdColors.header,
          border: Border(bottom: BorderSide(color: RdColors.line)),
        ),
        child: SafeArea(bottom: false, child: row),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RdColors.white8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2080C18), Color(0xC7080C18)],
        ),
      ),
      child: row,
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
    return _HeaderButton(
      tooltip: tooltip,
      size: size,
      pressed: favorite,
      onPressed: onPressed,
      child: Icon(
        favorite ? Icons.star : Icons.star_border,
        size: 20,
        color: RdColors.gold,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.operator,
    required this.i18n,
    required this.compact,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final portrait = compact ? 92.0 : 112.0;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: opPanelFill,
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        border: Border.all(color: RdColors.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: compact ? 12 : 14,
        children: [
          Wrap(
            spacing: compact ? 6 : 8,
            runSpacing: compact ? 6 : 8,
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
          Semantics(
            header: true,
            child: _FittedName(operator.name, maxSize: compact ? 40 : 48),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: compact ? 12 : 16,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Text(
                        operator.quote,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          height: 1.7,
                          color: RdColors.secondary,
                        ),
                      ),
                      if (operator.tags.isNotEmpty)
                        Semantics(
                          container: true,
                          label: i18n.t('operatorDetail.labels.baseTags'),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in operator.tags) OpChip.text(tag),
                            ],
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
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: compact ? 8 : 10,
                children: [
                  OpPortrait(
                    charId: operator.id,
                    name: operator.name,
                    size: portrait,
                    radius: compact ? 24 : 28,
                  ),
                  Text(
                    '★' * operator.rarity,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      letterSpacing: compact ? 1.2 : 1.56,
                      color: RdColors.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `fitOperatorName`: [maxSize] (48px PC / 40px phone), shrinking 1px at a
/// time down to 24px until the single line fits.
class _FittedName extends StatelessWidget {
  const _FittedName(this.name, {required this.maxSize});

  final String name;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = maxSize;
        TextStyle styleFor(double size) => TextStyle(
              fontSize: size,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.03 * size,
              color: RdColors.text,
            );
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        double measure(double size) {
          final painter = TextPainter(
            text: TextSpan(text: name, style: styleFor(size)),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        while (measure(size) > constraints.maxWidth && size > 24) {
          size -= 1;
        }
        return Text(
          name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: styleFor(size),
        );
      },
    );
  }
}

class _PlanActions extends StatelessWidget {
  const _PlanActions({
    required this.inPlan,
    required this.busy,
    required this.favorite,
    required this.showFavorite,
    required this.i18n,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final bool inPlan;
  final bool busy;
  final bool favorite;
  final bool showFavorite;
  final NexusI18n i18n;
  final VoidCallback onAdd;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final add = inPlan
        ? Semantics(
            button: true,
            enabled: false,
            child: Container(
              key: const Key('operator-detail-in-plan'),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x1F6EE7A8),
                borderRadius: BorderRadius.circular(RdRadii.control),
                border: Border.all(color: const Color(0x666EE7A8)),
              ),
              child: Text(
                i18n.t('rd.operators.detail.inPlan'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC8F5DC),
                ),
              ),
            ),
          )
        : RdButton(
            key: const Key('operator-detail-add-to-plan'),
            label: i18n.t('rd.operators.detail.addToPlan'),
            variant: RdButtonVariant.primary,
            height: 48,
            expand: true,
            busy: busy,
            onPressed: onAdd,
          );
    final open = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(showFavorite ? 12 : 14),
        side: const BorderSide(color: RdColors.tonalBorder),
      ),
      child: InkWell(
        key: const Key('operator-detail-open-plan'),
        borderRadius: BorderRadius.circular(showFavorite ? 12 : 14),
        onTap: onOpen,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            i18n.t('rd.operators.detail.openPlan'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: RdColors.linkText,
            ),
          ),
        ),
      ),
    );
    return Row(
      spacing: 10,
      children: [
        Expanded(child: add),
        open,
        if (showFavorite)
          Tooltip(
            message: i18n.t('rd.operators.detail.favorite'),
            child: Semantics(
              button: true,
              toggled: favorite,
              label: i18n.t('rd.operators.detail.favorite'),
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RdRadii.control),
                  side: const BorderSide(color: RdColors.white14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(RdRadii.control),
                  onTap: onToggleFavorite,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 20,
                      color: RdColors.gold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
  if (compact) {
    final height = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: RdColors.barrier,
      constraints: BoxConstraints(maxHeight: height * 0.65),
      builder: (context) => content,
    );
  }
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: i18n.t('rd.operators.detail.closeTerm'),
    barrierColor: RdColors.barrier,
    transitionDuration: const Duration(milliseconds: 160),
    transitionBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, animation, secondary) => SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: content,
          ),
        ),
      ),
    ),
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
        ? const BorderRadius.vertical(top: Radius.circular(22))
        : BorderRadius.circular(22);
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
                ? const Border(top: BorderSide(color: Color(0x2E82AAFF)))
                : Border.all(color: const Color(0x2E82AAFF)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1120), Color(0xFF09101D)],
            ),
            boxShadow: compact
                ? null
                : const [BoxShadow(color: Color(0x8C000000), blurRadius: 60)],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [Color(0x246DCCFF), Color(0x006DCCFF)],
                  stops: [0, 0.34],
                ),
              ),
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
                            tooltip:
                                widget.i18n.t('rd.operators.detail.closeTerm'),
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
      ),
    );
  }
}
