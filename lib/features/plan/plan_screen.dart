import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data_sources/region_code.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../domain/operator.dart';
import '../../domain/user_data.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/operator_service.dart';
import '../../services/plan_cost_service.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'plan_auto_persist.dart';
import 'plan_materials_grid.dart';
import 'plan_picker.dart';
import 'plan_widgets.dart';
import 'plan_totals.dart';

enum _PlanTab { operators, summary }

/// Plan page (`src/pages/plan/index.vue`) in the redesign layout.
///
/// Two tabs: the plan's operators (tap = open the operator plan; selection
/// mode removes several at once; favorites offer a one-tap start when the
/// plan is empty) and the aggregated summary across all planned operators.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  static const routeName = 'plan';

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _isLoading = true;
  bool _summaryLoading = false;
  String _errorMessage = '';
  String _summaryErrorMessage = '';
  String _pickerQuery = '';
  _PlanTab _activeTab = _PlanTab.operators;
  bool _selectionMode = false;
  List<String> _pendingRemovalIds = const [];
  List<OperatorSummary> _operators = const [];
  List<String> _favoriteOperatorIds = const [];
  List<String> _selectedOperatorIds = const [];
  UserPlan _userPlan = const UserPlan();
  Map<String, ItemEntry> _itemsById = const {};
  BuildingFormulaBundle _buildingFormulas = const BuildingFormulaBundle();
  List<OperatorDetail> _summaryDetails = const [];
  bool _summaryExpandRecipes = false;

  int _loadToken = 0;
  int _summaryToken = 0;
  PlanPickerController? _picker;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPlanOperators);
  }

  RegionCode get _region => ref.read(regionProvider);

  /// Loads favorites, operators, the saved plan and item references. A region
  /// switch or data refresh lands here too: it closes the picker and turns
  /// the "expand crafting formulas" toggle off.
  Future<void> _loadPlanOperators() async {
    final token = ++_loadToken;
    final region = _region;
    _closePicker();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _pickerQuery = '';
      _summaryExpandRecipes = false;
    });

    try {
      final userData = ref.read(userDataServiceProvider);
      final favoritesFuture = userData.getFavorites();
      final operatorsFuture = ref
          .read(operatorServiceProvider)
          .listOperators(OperatorQuery(region: region));
      final planFuture = userData.getUserPlan();
      final referenceFuture =
          loadPlanReferenceData(ref.read(itemServiceProvider), region);

      final favoriteIds = await favoritesFuture;
      final operatorList = await operatorsFuture;
      final plan = await planFuture;
      final references = await referenceFuture;
      if (!mounted || token != _loadToken) {
        return;
      }

      final known = {for (final operator in operatorList) operator.id};
      setState(() {
        _operators = operatorList;
        _userPlan = plan;
        _itemsById = references.itemsById;
        _buildingFormulas = references.formulas;
        _selectedOperatorIds =
            plan.selectedOperatorIds.where(known.contains).toList();
        _favoriteOperatorIds = favoriteIds.where(known.contains).toList();
      });
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('plan load failed', error, stackTrace);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _operators = const [];
        _favoriteOperatorIds = const [];
        _selectedOperatorIds = const [];
        _itemsById = const {};
        _buildingFormulas = const BuildingFormulaBundle();
        _userPlan = const UserPlan();
        _errorMessage = '$error';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
    _onSummaryInputsChanged();
  }

  /// `watch([activeTab, selectedOperatorIds, region], ...)`.
  void _onSummaryInputsChanged() {
    if (mounted && _activeTab == _PlanTab.summary) {
      _loadSummaryEntries();
    }
  }

  Future<void> _loadSummaryEntries() async {
    final token = ++_summaryToken;
    if (_selectedOperatorIds.isEmpty) {
      setState(() {
        _summaryDetails = const [];
        _summaryErrorMessage = '';
        _summaryLoading = false;
      });
      return;
    }

    setState(() {
      _summaryLoading = true;
      _summaryErrorMessage = '';
    });

    final region = _region;
    final service = ref.read(operatorServiceProvider);
    try {
      final details = await Future.wait([
        for (final id in _selectedOperatorIds)
          service.getOperatorDetail(region, id),
      ]);
      if (!mounted || token != _summaryToken) {
        return;
      }
      setState(() {
        _summaryDetails = details.whereType<OperatorDetail>().toList();
      });
    } catch (error) {
      if (!mounted || token != _summaryToken) {
        return;
      }
      setState(() {
        _summaryDetails = const [];
        _summaryErrorMessage = '$error';
      });
    } finally {
      if (mounted && token == _summaryToken) {
        setState(() => _summaryLoading = false);
      }
    }
  }

  Future<void> _addOperator(String operatorId) async {
    if (_selectedOperatorIds.contains(operatorId)) {
      return;
    }
    final saved = await ref
        .read(userDataServiceProvider)
        .saveUserPlanSelection([..._selectedOperatorIds, operatorId]);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedOperatorIds = saved;
      _userPlan = UserPlan(
        selectedOperatorIds: [...saved],
        operators: _userPlan.operators,
      );
    });
    _picker?.refresh();
    _onSummaryInputsChanged();
  }

  Future<void> _removeOperator(String operatorId) async {
    await ref.read(userDataServiceProvider).removeUserPlanOperator(operatorId);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedOperatorIds =
          _selectedOperatorIds.where((id) => id != operatorId).toList();
      _userPlan = UserPlan(
        selectedOperatorIds: [..._selectedOperatorIds],
        operators: _userPlan.operators
            .where((plan) => plan.operatorId != operatorId)
            .toList(),
      );
      _summaryDetails =
          _summaryDetails.where((detail) => detail.id != operatorId).toList();
    });
  }

  /// The confirm button of selection mode: no-op while nothing is marked.
  Future<void> _removeSelectedOperators() async {
    if (_pendingRemovalIds.isEmpty) {
      return;
    }
    for (final operatorId in [..._pendingRemovalIds]) {
      await _removeOperator(operatorId);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _pendingRemovalIds = const [];
    });
    _onSummaryInputsChanged();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _pendingRemovalIds = const [];
    });
  }

  void _togglePendingRemoval(String operatorId) {
    if (!_selectionMode) {
      return;
    }
    setState(() {
      _pendingRemovalIds = _pendingRemovalIds.contains(operatorId)
          ? _pendingRemovalIds.where((id) => id != operatorId).toList()
          : [..._pendingRemovalIds, operatorId];
    });
  }

  void _openOperatorPlan(String operatorId) {
    if (_selectionMode) {
      _togglePendingRemoval(operatorId);
      return;
    }
    context.push('/plan/$operatorId');
  }

  void _setTab(_PlanTab tab) {
    if (tab == _activeTab) {
      return;
    }
    setState(() {
      _activeTab = tab;
      // Leaving the operators tab ends selection mode.
      if (tab != _PlanTab.operators) {
        _selectionMode = false;
        _pendingRemovalIds = const [];
      }
    });
    _onSummaryInputsChanged();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  List<OperatorSummary> get _selectedOperators => [
        for (final id in _selectedOperatorIds)
          if (_operators.where((op) => op.id == id).firstOrNull case final op?)
            op,
      ];

  List<OperatorSummary> get _favoriteOperators => [
        for (final id in _favoriteOperatorIds)
          if (!_selectedOperatorIds.contains(id))
            if (_operators.where((op) => op.id == id).firstOrNull
                case final op?)
              op,
      ];

  List<OperatorSummary> get _pickerOperators => filterPlanPickerOperators(
        operators: _operators,
        selectedIds: _selectedOperatorIds,
        query: _pickerQuery,
        i18n: ref.read(i18nProvider),
      );

  void _closePicker() {
    final picker = _picker;
    if (picker != null && picker.context.mounted) {
      Navigator.of(picker.context).pop();
    }
    _picker = null;
  }

  Future<void> _openPicker() async {
    if (_picker != null) {
      return;
    }
    await showPlanOperatorPicker(
      context: context,
      onAttach: (controller) => _picker = controller,
      query: () => _pickerQuery,
      onQueryChanged: (value) => _pickerQuery = value,
      operators: () => _pickerOperators,
      onAdd: _addOperator,
    );
    _picker = null;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    ref.listen(regionProvider, (previous, next) => _loadPlanOperators());
    ref.listen(dataRevisionProvider, (previous, next) => _loadPlanOperators());

    final compact = context.rdLayout == RdLayout.compact;
    final selectedOperators = _selectedOperators;
    final onOperatorsTab = _activeTab == _PlanTab.operators;

    final tabs = Semantics(
      label: i18n.t('rd.plan.tabsLabel'),
      container: true,
      child: RdSegmented<_PlanTab>(
        segments: [
          RdSegment(_PlanTab.operators, i18n.t('planPage.tabs.operators')),
          RdSegment(_PlanTab.summary, i18n.t('planPage.tabs.summary')),
        ],
        selected: _activeTab,
        onChanged: _setTab,
        height: 44,
      ),
    );

    final actions = <Widget>[
      if (!_selectionMode && onOperatorsTab && selectedOperators.isNotEmpty)
        RdIconButton(
          key: const Key('plan-selection-action'),
          icon: Icons.delete_outline,
          tooltip: i18n.t('rd.plan.selectForRemoval'),
          onPressed: _toggleSelectionMode,
        ),
      if (_selectionMode) ...[
        Semantics(
          label: i18n.t('rd.plan.removeSelected'),
          child: RdButton(
            key: const Key('plan-selection-action'),
            variant: RdButtonVariant.danger,
            icon: Icons.check,
            label: _pendingRemovalIds.isEmpty
                ? i18n.t('planPage.actions.removeOperator')
                : i18n.t('rd.plan.removeCount', {
                    'count': _pendingRemovalIds.length,
                  }),
            onPressed: _removeSelectedOperators,
          ),
        ),
        RdIconButton(
          key: const Key('plan-selection-cancel'),
          icon: Icons.close,
          tooltip: i18n.t('rd.plan.cancelSelection'),
          onPressed: _toggleSelectionMode,
        ),
      ],
      if (!_selectionMode)
        compact
            ? PlanAccentIconButton(
                key: const Key('plan-picker-open'),
                icon: Icons.add,
                tooltip: i18n.t('planPage.actions.addOperator'),
                onPressed: _openPicker,
              )
            : RdButton(
                key: const Key('plan-picker-open'),
                variant: RdButtonVariant.primary,
                icon: Icons.add,
                label: i18n.t('planPage.actions.addOperator'),
                onPressed: _openPicker,
              ),
    ];

    final header = RdPageHeader(
      title: i18n.t('shell.nav.plan'),
      subtitle: i18n.t('planPage.topBar.description'),
      onBack: _goBack,
      backTooltip: i18n.t('common.back'),
      actions: actions,
      bottom: compact ? tabs : null,
    );

    final Widget body;
    if (_errorMessage.isNotEmpty) {
      body = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('planPage.states.errorTitle'),
        detail: _errorMessage,
        action: RdButton(
          label: i18n.t('planPage.actions.retry'),
          onPressed: _loadPlanOperators,
          variant: RdButtonVariant.tonal,
          height: context.rdLayout == RdLayout.compact ? 44 : 40,
        ),
      );
    } else if (_isLoading) {
      body = _OperatorsSkeleton(label: i18n.t('rd.plan.loading'));
    } else if (onOperatorsTab) {
      body = _buildOperatorsTab(i18n, selectedOperators, compact);
    } else {
      body = _buildSummaryTab(i18n, compact);
    }

    return PlanPageFrame(
      header: header,
      children: [
        if (!compact)
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: tabs,
            ),
          ),
        body,
      ],
    );
  }

  Widget _buildOperatorsTab(
    NexusI18n i18n,
    List<OperatorSummary> selectedOperators,
    bool compact,
  ) {
    final favoriteOperators = _favoriteOperators;
    final hasSelected = selectedOperators.isNotEmpty;

    RdAutoGrid grid(List<Widget> tiles) => RdAutoGrid(
          columns: compact ? 3 : null,
          minTileWidth: compact ? null : 132,
          gap: compact ? 10 : 12,
          children: tiles,
        );

    final Widget content;
    if (hasSelected) {
      content = grid([
        for (final operator in selectedOperators)
          PlanOperatorTile(
            key: ValueKey('plan-operator-${operator.id}'),
            operatorId: operator.id,
            name: operator.name,
            rarity: operator.rarity,
            mode: _selectionMode ? PlanTileMode.pick : PlanTileMode.open,
            pending: _pendingRemovalIds.contains(operator.id),
            semanticLabel: !_selectionMode
                ? operator.name
                : i18n.t(
                    _pendingRemovalIds.contains(operator.id)
                        ? 'rd.plan.unmarkForRemoval'
                        : 'rd.plan.markForRemoval',
                    {'name': operator.name},
                  ),
            onTap: () => _openOperatorPlan(operator.id),
          ),
      ]);
    } else if (favoriteOperators.isNotEmpty) {
      content = grid([
        for (final operator in favoriteOperators)
          PlanOperatorTile(
            key: ValueKey('plan-favorite-${operator.id}'),
            operatorId: operator.id,
            name: operator.name,
            rarity: operator.rarity,
            mode: PlanTileMode.favorite,
            footer: i18n.t(
              compact ? 'rd.plan.addToPlanShort' : 'rd.plan.addToPlan',
            ),
            semanticLabel:
                i18n.t('rd.plan.addNamedToPlan', {'name': operator.name}),
            onTap: () => _addOperator(operator.id),
          ),
      ]);
    } else {
      content = RdStatePanel(
        kind: RdStateKind.empty,
        layout: RdStateLayout.left,
        surface: RdStateSurface.inset,
        title: i18n.t('planPage.states.emptyTitle'),
        message: i18n.t('planPage.states.emptyDescription'),
      );
    }

    return RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdHeading(
            hasSelected
                ? i18n.t('planPage.sections.selected')
                : i18n.t('planPage.sections.favorites'),
            description: _selectionMode
                ? i18n.t('planPage.states.selectionDescription')
                : hasSelected
                    ? i18n.t('planPage.states.selectedDescription')
                    : i18n.t('planPage.states.favoritesDescription'),
            fontSize: compact ? 16 : 17,
            descriptionStyle: compact
                ? RdText.caption
                : RdText.caption.copyWith(fontSize: 13),
          ),
          SizedBox(height: compact ? 12 : 14),
          content,
        ],
      ),
    );
  }

  ({
    List<OperatorDetail> details,
    UserPlan plan,
    Map<String, ItemEntry> items,
    PlanTotals<PlanAggregateBreakdown>? totals,
  })? _summaryMemo;

  /// Summary totals, recomputed only when the loaded details, the plan or
  /// the item references change (not on every rebuild of the tab).
  PlanTotals<PlanAggregateBreakdown>? _summaryTotals() {
    final memo = _summaryMemo;
    if (memo != null &&
        identical(memo.details, _summaryDetails) &&
        identical(memo.plan, _userPlan) &&
        identical(memo.items, _itemsById)) {
      return memo.totals;
    }
    final costService = ref.read(planCostServiceProvider);
    final entries = resolvePlanEntries(costService, _summaryDetails, _userPlan);
    final totals = entries.isEmpty
        ? null
        : PlanTotals.aggregate(costService, entries, _itemsById);
    _summaryMemo = (
      details: _summaryDetails,
      plan: _userPlan,
      items: _itemsById,
      totals: totals,
    );
    return totals;
  }

  Widget _buildSummaryTab(NexusI18n i18n, bool compact) {
    if (_summaryErrorMessage.isNotEmpty) {
      return RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('planPage.summary.errorTitle'),
        detail: _summaryErrorMessage,
      );
    }
    if (_summaryLoading) {
      return _SummarySkeleton(label: i18n.t('rd.plan.loading'));
    }

    final totals = _summaryTotals();
    if (totals == null) {
      return RdStatePanel(
        kind: RdStateKind.empty,
        layout: RdStateLayout.left,
        surface: RdStateSurface.inset,
        title: i18n.t('planPage.summary.emptyTitle'),
        message: i18n.t('planPage.summary.emptyDescription'),
      );
    }

    final entries = totals.entries;
    final breakdown = totals.breakdown;
    final farming = totals.farming;
    final showExp = totals.showExp;
    final showLmd = totals.showLmd;
    final showOverview = showExp || showLmd;
    final lmdItemId = totals.lmdId;
    final lmdShortage = totals.lmdShortage;
    final expLabel = i18n.t('planPage.summary.expLabel');
    final lmdLabel = i18n.t('planPage.summary.lmdLabel');
    final gap = compact ? 10.0 : 14.0;

    final countCard = _CountCard(
      label: i18n.t('planPage.summary.operators'),
      value: formatPlanNumber(breakdown.operatorCount),
      compact: compact,
    );

    final resources = RdAutoGrid(
      columns: 2,
      gap: compact ? 10 : 12,
      children: [
        if (showExp)
          PlanResourceCard(
            label: expLabel,
            itemId: expItemId,
            iconId: _itemsById[expItemId]?.iconId,
            itemName: _itemsById[expItemId]?.name ?? expLabel,
            value: formatPlanNumber(farming.exp),
            tint: PlanColors.expTint,
            linkLabel: i18n.t('rd.plan.itemDetail', {
              'name': _itemsById[expItemId]?.name ?? expLabel,
            }),
            onOpenItem: () => context.push('/items/$expItemId'),
          ),
        if (showLmd)
          PlanResourceCard(
            label: lmdLabel,
            itemId: lmdItemId,
            iconId: farming.lmdItem?.iconId,
            itemName: farming.lmdItem?.name ?? lmdLabel,
            value: formatPlanNumber(farming.lmd),
            tint: PlanColors.lmdTint,
            linkLabel: i18n.t('rd.plan.itemDetail', {
              'name': farming.lmdItem?.name ?? lmdLabel,
            }),
            shortageLabel: lmdShortage > 0
                ? i18n.t('planPage.summary.shortageOnly', {
                    'shortage': formatPlanNumber(lmdShortage),
                  })
                : null,
            onOpenItem: () => context.push('/items/$lmdItemId'),
          ),
      ],
    );

    final farmingCard = RdCard.tile(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdHeading(
            i18n.t('planPage.summary.farmingTitle'),
            description: i18n.t('planPage.summary.farmingDescription'),
            descriptionStyle: RdText.caption,
          ),
          if (showExp) ...[
            const SizedBox(height: 10),
            PlanFarmingRow(
              boxed: true,
              label: expLabel,
              code: farming.expStage.code,
              chip: i18n.t('planPage.summary.runs', {
                'count': farming.expStage.runs,
              }),
            ),
          ],
          if (showLmd) ...[
            const SizedBox(height: 8),
            PlanFarmingRow(
              boxed: true,
              label: lmdLabel,
              code: farming.lmdStage.code,
              chip: i18n.t('planPage.summary.runs', {
                'count': farming.lmdStage.runs,
              }),
            ),
          ],
          const SizedBox(height: 8),
          PlanFarmingRow(
            boxed: true,
            gold: true,
            label: '$expLabel + $lmdLabel',
            chip: i18n.t('planPage.summary.totalSanity', {
              'count': formatPlanNumber(farming.totalSanity),
            }),
          ),
        ],
      ),
    );

    final validation = breakdown.errors.isEmpty
        ? null
        : PlanValidationBox(
            title: i18n.t('planPage.summary.validationTitle'),
            messages: breakdown.errors,
          );

    final materialsHeading = RdHeading(
      i18n.t('planPage.summary.materialsTitle'),
      description: i18n.t('planPage.summary.materialsDescription'),
      fontSize: compact ? 15 : 17,
      descriptionStyle:
          compact ? RdText.caption : RdText.caption.copyWith(fontSize: 13),
    );
    final materialsGrid = PlanMaterialsGrid(
      materials: breakdown.materials,
      emptyLabel: i18n.t('planPage.detail.noMaterials'),
      itemsById: _itemsById,
      formulas: _buildingFormulas,
      expanded: _summaryExpandRecipes,
      showShortage: true,
      onToggleExpand: () =>
          setState(() => _summaryExpandRecipes = !_summaryExpandRecipes),
    );

    final routes = Semantics(
      label: i18n.t('rd.plan.routesLabel'),
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 8 : 10),
            _RouteCard(
              entry: entries[i],
              compact: compact,
              routeLabel: i18n.t('planPage.summary.routeLabel', {
                'current':
                    'E${entries[i].plan.current.elite} Lv.${entries[i].plan.current.level}',
                'target':
                    'E${entries[i].plan.target.elite} Lv.${entries[i].plan.target.level}',
              }),
              actionLabel: i18n.t('planPage.summary.openDetail'),
              onOpen: () => _openOperatorPlan(entries[i].detail.id),
            ),
          ],
        ],
      ),
    );

    List<Widget> spaced(List<Widget?> children) {
      final present = children.whereType<Widget>().toList();
      return [
        for (var i = 0; i < present.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          present[i],
        ],
      ];
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced([
          countCard,
          if (showOverview) resources,
          if (showOverview) farmingCard,
          validation,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              materialsHeading,
              const SizedBox(height: 12),
              materialsGrid,
            ],
          ),
          routes,
        ]),
      );
    }

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced([
        countCard,
        if (showOverview) resources,
        if (showOverview) farmingCard,
        validation,
        routes,
      ]),
    );
    final right = RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [materialsHeading, const SizedBox(height: 14), materialsGrid],
      ),
    );

    // `flex: 1 1 320px; max-width: 420px` | `flex: 999 1 420px`, wrapping.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 18.0;
        if (constraints.maxWidth < 320 + gutter + 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: gutter), right],
          );
        }
        final free = constraints.maxWidth - gutter - 740;
        final leftWidth = (320 + free / 1000).clamp(320.0, 420.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: left),
            const SizedBox(width: gutter),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/// "집계 오퍼레이터" count card.
class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.96,
        color: RdColors.muted,
      ),
    );
    final valueText = Text(
      value,
      key: const Key('plan-summary-count'),
      style: RdText.mono(fontSize: compact ? 24 : 26),
    );
    return RdCard(
      radius: RdRadii.tile,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [Expanded(child: labelText), valueText],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            ),
    );
  }
}

/// Per-operator route row with the "open detail" link.
class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.entry,
    required this.compact,
    required this.routeLabel,
    required this.actionLabel,
    required this.onOpen,
  });

  final PlanCostEntry entry;
  final bool compact;
  final String routeLabel;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      radius: compact ? 16 : RdRadii.tile,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          RdPortrait(
            charId: entry.detail.id,
            name: entry.detail.name,
            size: compact ? 44 : 48,
            radius: 18,
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.detail.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  routeLabel,
                  style: RdText.mono(
                    fontSize: compact ? 11 : 12,
                    color: RdColors.secondary2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          RdButton(
            label: actionLabel,
            onPressed: onOpen,
            variant: RdButtonVariant.tonal,
            height: compact ? 44 : 38,
          ),
        ],
      ),
    );
  }
}

class _OperatorsSkeleton extends StatelessWidget {
  const _OperatorsSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    return Semantics(
      label: label,
      container: true,
      child: RdCard.tile(
        child: RdPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RdSkeleton(height: 20, widthFactor: 0.36),
              const SizedBox(height: 14),
              RdAutoGrid(
                columns: compact ? 2 : null,
                minTileWidth: compact ? null : 132,
                gap: compact ? 10 : 12,
                children: [
                  for (var index = 0; index < 4; index++)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RdColors.inner,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          RdSkeleton(
                            width: 84,
                            height: 84,
                            radius: 24,
                            color: RdColors.soft,
                          ),
                          SizedBox(height: 10),
                          RdSkeleton(widthFactor: 0.72),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    const block = RdSkeleton(
      height: 96,
      radius: 16,
      color: RdColors.white5,
    );
    return Semantics(
      label: label,
      container: true,
      child: RdCard.tile(
        child: RdPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RdSkeleton(height: 20, widthFactor: 0.36),
              const SizedBox(height: 12),
              if (compact) ...[
                block,
                const SizedBox(height: 12),
                block,
                const SizedBox(height: 12),
                block,
              ] else
                const RdAutoGrid(
                  columns: 3,
                  children: [block, block, block],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
