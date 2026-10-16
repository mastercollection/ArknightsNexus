import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data_sources/region_code.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../domain/penguin_matrix.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../ui/nexus_ui.dart'
    show ItemIcon, NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import 'item_format.dart';
import 'owned_count_editor.dart';

enum PenguinSortKey { dropRate, sampleCount }

/// Port of `src/pages/items/[itemId].vue`, laid out after the redesign
/// board `PcItemDetail`: a header bar with the icon, tier / kind chips and
/// the inline owned-count stepper; the description and building recipe
/// cards next to the Penguin Stats drops (stacked on phones).
///
/// The page appears as soon as the item is resolved from the local data;
/// the recipe (local) and the Penguin Stats drops (network) fill in their
/// own cards as they arrive.
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({
    required this.itemId,
    super.key,
  });

  static const routeName = 'item-detail';

  /// `penguinServerOptions` display order.
  static const penguinServers = [
    PenguinServer.cn,
    PenguinServer.kr,
    PenguinServer.jp,
    PenguinServer.us,
  ];

  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _LinkedFormula {
  const _LinkedFormula(this.formulaId, this.roomType, this.costs);

  final String formulaId;

  /// `manufacture` or `workshop` (the `rd.items.room.*` key).
  final String roomType;
  final List<FormulaCost> costs;
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  ItemEntry? _item;
  bool _isLoading = true;
  String _errorMessage = '';
  List<PenguinMatrixEntry> _penguinDrops = const [];
  String _penguinErrorMessage = '';
  bool _isPenguinLoading = false;
  bool _isStageCodeLoading = false;
  BuildingFormulaBundle _formulas = const BuildingFormulaBundle();
  bool _isFormulaLoading = false;
  String _buildingFormulaErrorMessage = '';
  Map<String, ItemEntry> _allItems = const {};
  Map<String, String> _stageCodeMap = const {};
  PenguinServer _penguinServer = PenguinServer.cn;
  PenguinSortKey _penguinSortKey = PenguinSortKey.dropRate;
  final _savingItemIds = ValueNotifier<Set<String>>(const {});
  int _loadToken = 0;
  int _penguinToken = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(regionProvider, (_, __) => unawaited(_loadItem()));
    ref.listenManual(dataRevisionProvider, (_, __) => unawaited(_loadItem()));
    unawaited(_loadItem());
  }

  @override
  void didUpdateWidget(ItemDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      unawaited(_loadItem());
    }
  }

  @override
  void dispose() {
    _savingItemIds.dispose();
    super.dispose();
  }

  /// `loadItem`: resolves the item from the local data first and shows the
  /// page; formulas, stage codes and the Penguin drops then load on their
  /// own.
  Future<void> _loadItem() async {
    final token = ++_loadToken;
    final itemId = widget.itemId.trim();
    final region = ref.read(regionProvider);
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _item = null;
      _penguinDrops = const [];
      _penguinErrorMessage = '';
      _formulas = const BuildingFormulaBundle();
      _buildingFormulaErrorMessage = '';
      _allItems = const {};
      _stageCodeMap = const {};
    });

    bool stale() => !mounted || token != _loadToken;

    try {
      final itemService = ref.read(itemServiceProvider);
      final items = itemId.isEmpty
          ? const <ItemEntry>[]
          : await itemService.listItems(ItemQuery(region: region));
      if (stale()) {
        return;
      }
      ItemEntry? item;
      for (final entry in items) {
        if (entry.itemId == itemId) {
          item = entry;
          break;
        }
      }
      setState(() {
        _item = item;
        _allItems = {for (final entry in items) entry.itemId: entry};
        _isLoading = false;
      });
      if (item != null) {
        unawaited(_loadFormulas(token, region));
        unawaited(_loadStageCodes(token, region));
        unawaited(_loadPenguinDrops(item.itemId));
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('item detail load failed', error, stackTrace);
      if (!stale()) {
        setState(() {
          _errorMessage = '$error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFormulas(int token, RegionCode region) async {
    setState(() => _isFormulaLoading = true);
    var formulas = const BuildingFormulaBundle();
    var formulaError = '';
    try {
      formulas =
          await ref.read(itemServiceProvider).listBuildingFormulas(region);
    } catch (error) {
      formulaError = '$error';
    }
    if (!mounted || token != _loadToken) {
      return;
    }
    setState(() {
      _formulas = formulas;
      _buildingFormulaErrorMessage = formulaError;
      _isFormulaLoading = false;
    });
  }

  /// Stage codes only label the Penguin rows; without them the stage ids
  /// are shown.
  Future<void> _loadStageCodes(int token, RegionCode region) async {
    setState(() => _isStageCodeLoading = true);
    var codes = const <String, String>{};
    try {
      codes =
          await ref.read(regionSyncServiceProvider).getRegionStageCodes(region);
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('stage codes load failed', error, stackTrace);
    }
    if (!mounted || token != _loadToken) {
      return;
    }
    setState(() {
      _stageCodeMap = codes;
      _isStageCodeLoading = false;
    });
  }

  Future<void> _loadPenguinDrops(String itemId) async {
    final token = ++_penguinToken;
    setState(() {
      _isPenguinLoading = true;
      _penguinErrorMessage = '';
    });
    try {
      final drops = await ref
          .read(penguinStatsServiceProvider)
          .getItemMatrix(itemId, server: _penguinServer);
      if (mounted && token == _penguinToken) {
        setState(() => _penguinDrops = drops);
      }
    } catch (error) {
      if (mounted && token == _penguinToken) {
        setState(() {
          _penguinDrops = const [];
          _penguinErrorMessage = '$error';
        });
      }
    } finally {
      if (mounted && token == _penguinToken) {
        setState(() => _isPenguinLoading = false);
      }
    }
  }

  void _setPenguinServer(PenguinServer server) {
    if (server == _penguinServer) {
      return;
    }
    setState(() => _penguinServer = server);
    final item = _item;
    if (item != null) {
      unawaited(_loadPenguinDrops(item.itemId));
    }
  }

  bool _isSaving(String itemId) => _savingItemIds.value.contains(itemId);

  void _setItemSaving(String itemId, bool saving) {
    final next = {..._savingItemIds.value};
    if (saving) {
      next.add(itemId);
    } else {
      next.remove(itemId);
    }
    _savingItemIds.value = next;
  }

  void _replaceOwnedCount(String itemId, int count) {
    final item = _item;
    if (item == null || item.itemId != itemId) {
      return;
    }
    setState(() => _item = item.copyWith(ownedCount: count));
  }

  /// Same rules as the list (`updateOwnedCount`): optimistic write,
  /// per-item saving lock, rollback and error toast on failure.
  Future<void> _updateOwnedCount(String itemId, int nextValue) async {
    final item = _item;
    if (item == null || item.itemId != itemId) {
      return;
    }
    final normalized = nextValue < 0 ? 0 : nextValue;
    final previous = item.ownedCount;
    if (normalized == previous || _isSaving(itemId)) {
      return;
    }

    _replaceOwnedCount(itemId, normalized);
    _setItemSaving(itemId, true);
    try {
      final saved = await ref
          .read(userDataServiceProvider)
          .saveUserItemCount(itemId, normalized);
      if (mounted) {
        _replaceOwnedCount(itemId, saved);
      }
    } catch (error) {
      if (mounted) {
        _replaceOwnedCount(itemId, previous);
        showNexusMessage(context, '$error', type: NexusMessageType.error);
      }
    } finally {
      _setItemSaving(itemId, false);
    }
  }

  List<PenguinMatrixEntry> get _sortedPenguinDrops {
    final entries = [..._penguinDrops];
    int byStage(PenguinMatrixEntry l, PenguinMatrixEntry r) =>
        l.stageId.compareTo(r.stageId);
    if (_penguinSortKey == PenguinSortKey.sampleCount) {
      entries.sort((l, r) {
        final byTimes = r.times.compareTo(l.times);
        if (byTimes != 0) {
          return byTimes;
        }
        final byRate = r.dropRate.compareTo(l.dropRate);
        return byRate != 0 ? byRate : byStage(l, r);
      });
    } else {
      entries.sort((l, r) {
        final byRate = r.dropRate.compareTo(l.dropRate);
        if (byRate != 0) {
          return byRate;
        }
        final byTimes = r.times.compareTo(l.times);
        return byTimes != 0 ? byTimes : byStage(l, r);
      });
    }
    return entries;
  }

  /// `linkedBuildingFormulas`.
  List<_LinkedFormula> get _linkedBuildingFormulas {
    final item = _item;
    if (item == null) {
      return const [];
    }
    final linked = <_LinkedFormula>[];
    for (final product in item.buildingProductList) {
      final isWorkshop = product.roomType.toUpperCase() == 'WORKSHOP';
      final costs = isWorkshop
          ? _formulas.workshopFormulas
              .where((entry) => entry.formulaId == product.formulaId)
              .firstOrNull
              ?.costs
          : _formulas.manufactFormulas
              .where((entry) => entry.formulaId == product.formulaId)
              .firstOrNull
              ?.costs;
      if (costs != null && costs.isNotEmpty) {
        linked.add(
          _LinkedFormula(
            product.formulaId,
            isWorkshop ? 'workshop' : 'manufacture',
            costs,
          ),
        );
      }
    }
    return linked;
  }

  /// `router.push('/items')`: return to the list (pop when it is underneath).
  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/items');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final item = _item;

    final List<Widget> body;
    if (_isLoading) {
      body = [
        Semantics(
          label: i18n.t('itemsPage.states.loading'),
          child: const _DetailLoading(),
        ),
      ];
    } else if (_errorMessage.isNotEmpty) {
      body = [
        RdStatePanel(
          kind: RdStateKind.error,
          layout: RdStateLayout.left,
          title: i18n.t('itemsDetail.states.error'),
          message: _errorMessage,
        ),
      ];
    } else if (item == null) {
      body = [
        RdStatePanel(
          kind: RdStateKind.empty,
          layout: RdStateLayout.left,
          title: i18n.t('itemsDetail.states.notFound'),
          message: i18n.t('itemsDetail.states.notFoundDescription'),
          action: RdButton(
            label: i18n.t('itemsDetail.states.backToList'),
            variant: RdButtonVariant.primary,
            height: compact ? 48 : 44,
            onPressed: _backToList,
          ),
        ),
      ];
    } else {
      body = _buildDetail(i18n, item, compact);
    }

    final title = item?.name ?? i18n.t('itemsDetail.topBar.title');
    final backTooltip = i18n.t('rd.items.backToList');
    final chips = item == null ? null : _chipsFor(i18n, item);
    final stepper = item == null
        ? null
        : OwnedCountStepper(
            key: ValueKey('owned-${item.itemId}'),
            item: item,
            savingItemIds: _savingItemIds,
            height: compact ? 44 : 40,
            fieldWidth: compact ? 96 : 72,
            onCommit: (value) => _updateOwnedCount(item.itemId, value),
          );

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            _CompactDetailBar(
              title: title,
              backTooltip: backTooltip,
              onBack: _backToList,
              item: item,
            )
          else
            _WideDetailHeader(
              title: title,
              backTooltip: backTooltip,
              onBack: _backToList,
              item: item,
              chips: chips,
              ownedLabel: i18n.t('rd.items.ownedLabel'),
              stepper: stepper,
            ),
          Expanded(
            child: ListView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                  : const EdgeInsets.fromLTRB(32, 24, 32, 32),
              children: [
                if (compact && chips != null && stepper != null) ...[
                  _CompactSummaryCard(
                    chips: chips,
                    ownedLabel: i18n.t('rd.items.ownedLabel'),
                    stepper: stepper,
                  ),
                  const SizedBox(height: 14),
                ],
                ...body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _chipsFor(NexusI18n i18n, ItemEntry item) {
    final kind = itemKindOf(item);
    final tier = itemTierOf(item);
    return [
      if (itemKindShowsTier(kind) && tier > 0) 'T$tier',
      i18n.t('rd.items.kind.${kind.name}'),
    ];
  }

  List<Widget> _buildDetail(NexusI18n i18n, ItemEntry item, bool compact) {
    final description = _buildDescriptionSection(i18n, item);
    final recipe = _buildRecipeSection(i18n, item);
    final penguin = _buildPenguinSection(i18n, compact);
    final left = [
      if (description != null) description,
      if (recipe != null) recipe,
    ];
    final gap = compact ? 14.0 : 20.0;
    Widget stack(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) SizedBox(height: gap),
              child,
            ],
          ],
        );
    return [
      // The item id is a development aid (`import.meta.env.DEV`).
      if (kDebugMode) ...[
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: item.itemId,
                style: RdText.mono(fontSize: 12, color: RdColors.text3),
              ),
              TextSpan(text: ' · ${i18n.t('rd.items.devOnly')}'),
            ],
          ),
          style: const TextStyle(fontSize: 12, color: RdColors.text3),
        ),
        const SizedBox(height: 12),
      ],
      if (compact || left.isEmpty)
        stack([...left, penguin])
      else
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 860) {
              return stack([...left, penguin]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stack(left)),
                SizedBox(width: gap),
                Expanded(child: penguin),
              ],
            );
          },
        ),
    ];
  }

  /// Description card with the usage and obtain lines; hidden when the data
  /// has none of them.
  Widget? _buildDescriptionSection(NexusI18n i18n, ItemEntry item) {
    final description = item.description.trim();
    final usage = item.usage.trim();
    final obtain = item.obtainApproach.trim();
    final rows = [
      if (usage.isNotEmpty) (i18n.t('itemsDetail.sections.usage'), usage),
      if (obtain.isNotEmpty)
        (i18n.t('itemsDetail.labels.obtainApproach'), obtain),
    ];
    if (description.isEmpty && rows.isEmpty) {
      return null;
    }
    return _SectionCard(
      title: i18n.t('itemsDetail.sections.description'),
      children: [
        if (description.isNotEmpty)
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 22 / 14,
              color: RdColors.text2,
            ),
          ),
        if (description.isNotEmpty && rows.isNotEmpty)
          const SizedBox(
            height: 1,
            child: ColoredBox(color: RdColors.hairline),
          ),
        if (rows.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, (label, value)) in rows.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 20 / 13,
                            color: RdColors.text3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 20 / 13,
                            color: RdColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Building recipe card: shown while the formulas load for an item that
  /// has building products, then only when a linked formula has costs or
  /// the formula load failed.
  Widget? _buildRecipeSection(NexusI18n i18n, ItemEntry item) {
    final title = i18n.t('itemsDetail.sections.buildingRecipes');
    if (_isFormulaLoading) {
      if (item.buildingProductList.isEmpty) {
        return null;
      }
      return _SectionCard(
        title: title,
        children: [
          RdPulse(
            child: Column(
              children: [
                for (var i = 0; i < 2; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: const _SkeletonRow(),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    final linked = _linkedBuildingFormulas;
    if (linked.isEmpty && _buildingFormulaErrorMessage.isEmpty) {
      return null;
    }
    final rooms = {for (final formula in linked) formula.roomType};
    return _SectionCard(
      title: title,
      trailing: [
        for (final room in rooms)
          RdPill(
            label: i18n.t('rd.items.room.$room'),
            color: RdColors.accentSoft,
            textColor: RdColors.accentHover,
          ),
      ],
      children: [
        if (_buildingFormulaErrorMessage.isNotEmpty)
          RdStatePanel(
            kind: RdStateKind.error,
            layout: RdStateLayout.left,
            surface: RdStateSurface.inner,
            title: i18n.t('itemsDetail.states.buildingFormulaError'),
            message: _buildingFormulaErrorMessage,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final formula in linked)
                for (final (index, cost) in formula.costs.indexed)
                  Padding(
                    key: ValueKey('${formula.formulaId}:${cost.id}'),
                    padding: EdgeInsets.only(
                      top: index == 0 && formula == linked.first ? 0 : 8,
                    ),
                    child: _FormulaCostRow(
                      cost: cost,
                      meta: _allItems[cost.id],
                      metaLabel: _costMeta(i18n, cost),
                      openLabel: i18n.t(
                        'rd.items.openItem',
                        {'name': _allItems[cost.id]?.name ?? cost.id},
                      ),
                      onOpen: _allItems.containsKey(cost.id)
                          ? () => context.push('/items/${cost.id}')
                          : null,
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  /// "T3 · 재료" for a known ingredient, the formula's cost type otherwise.
  String _costMeta(NexusI18n i18n, FormulaCost cost) {
    final meta = _allItems[cost.id];
    if (meta == null) {
      return cost.type;
    }
    final kind = itemKindOf(meta);
    final tier = itemTierOf(meta);
    final label = i18n.t('rd.items.kind.${kind.name}');
    return itemKindShowsTier(kind) && tier > 0 ? 'T$tier · $label' : label;
  }

  Widget _buildPenguinSection(NexusI18n i18n, bool compact) {
    final Widget body;
    if (_isPenguinLoading || _isStageCodeLoading) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RdColors.text3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i18n.t('rd.items.penguinLoading'),
                    style: const TextStyle(fontSize: 13, color: RdColors.text3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RdPulse(
            child: Column(
              children: [
                for (var i = 0; i < 6; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: const _SkeletonRow(),
                  ),
              ],
            ),
          ),
        ],
      );
    } else if (_penguinErrorMessage.isNotEmpty) {
      body = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        surface: RdStateSurface.inner,
        title: i18n.t('itemsDetail.states.penguinError'),
        message: _penguinErrorMessage,
      );
    } else if (_penguinDrops.isNotEmpty) {
      final rateLabel = i18n.t('itemsDetail.labels.dropRate');
      final timesLabel = i18n.t('itemsDetail.labels.sampleCount');
      final bestRate = _penguinDrops.fold<double>(
        0,
        (best, entry) => entry.dropRate > best ? entry.dropRate : best,
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, entry) in _sortedPenguinDrops.indexed)
            Padding(
              key: ValueKey(
                '${entry.stageId}:${entry.start ?? 'none'}:${entry.end ?? 'none'}',
              ),
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: _PenguinDropRow(
                compact: compact,
                stageLabel: penguinStageLabel(entry.stageId, _stageCodeMap),
                dropRate: entry.dropRate,
                barFraction: bestRate > 0 ? entry.dropRate / bestRate : 0,
                rateLabel: rateLabel,
                times: entry.times,
                timesLabel: timesLabel,
              ),
            ),
        ],
      );
    } else {
      body = Text(
        i18n.t('itemsDetail.states.noPenguinDrops'),
        style: const TextStyle(fontSize: 14, color: RdColors.text2),
      );
    }

    final sortSelect = RdSelect<PenguinSortKey>(
      label: i18n.t('rd.items.sortLabel'),
      width: compact ? 96 : 112,
      height: compact ? 44 : 36,
      value: _penguinSortKey,
      options: [
        for (final key in PenguinSortKey.values)
          RdSelectOption(key, i18n.t('itemsDetail.sort.${key.name}')),
      ],
      onChanged: (key) => setState(() => _penguinSortKey = key),
    );
    final serverSelect = RdSelect<PenguinServer>(
      label: i18n.t('rd.items.serverLabel'),
      width: compact ? 76 : 88,
      height: compact ? 44 : 36,
      value: _penguinServer,
      options: [
        for (final server in ItemDetailScreen.penguinServers)
          RdSelectOption(server, server.value),
      ],
      onChanged: _setPenguinServer,
    );

    return _SectionCard(
      title: i18n.t('itemsDetail.sections.penguinDrops'),
      trailing: [sortSelect, serverSelect],
      children: [
        body,
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            i18n.t(
              'itemsDetail.labels.dropSourcePenguin',
              {'server': _penguinServer.value},
            ),
            style: const TextStyle(fontSize: 12, color: RdColors.text3),
          ),
        ),
      ],
    );
  }
}

/// Surface-2 card with a section title (and controls or chips after it).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing = const [],
  });

  final String title;
  final List<Widget> trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    return RdCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: RdText.sectionTitle),
              ),
              if (trailing.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, widget) in trailing.indexed) ...[
                      if (index > 0) const SizedBox(width: 8),
                      widget,
                    ],
                  ],
                ),
            ],
          ),
          for (final child in children) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}

/// Tier / kind chip of the detail header.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.label);

  final String label;

  static final _tierLabel = RegExp(r'^T\d+$');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RdColors.surface3,
        borderRadius: BorderRadius.circular(RdRadii.chip),
        border: Border.all(color: RdColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: _tierLabel.hasMatch(label)
                ? RdText.mono(fontSize: 12, color: RdColors.text2)
                : const TextStyle(fontSize: 12, color: RdColors.text2),
          ),
        ],
      ),
    );
  }
}

Widget _chipRow(List<String> chips) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final chip in chips) _HeaderChip(chip)],
    );

/// PC header bar (`PcItemDetail`): back, icon, name with chips, and the
/// owned-count stepper.
class _WideDetailHeader extends StatelessWidget {
  const _WideDetailHeader({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    required this.item,
    required this.chips,
    required this.ownedLabel,
    required this.stepper,
  });

  final String title;
  final String backTooltip;
  final VoidCallback onBack;
  final ItemEntry? item;
  final List<String>? chips;
  final String ownedLabel;
  final Widget? stepper;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final chips = this.chips;
    final stepper = this.stepper;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: Row(
        children: [
          RdIconButton(
            icon: Icons.chevron_left,
            tooltip: backTooltip,
            size: 40,
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
          if (item != null) ...[
            ExcludeSemantics(
              child: ItemIcon(
                itemId: item.itemId,
                iconId: item.iconId,
                name: item.name,
                size: 56,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RdText.pageTitle,
                  ),
                ),
                if (chips != null) ...[
                  const SizedBox(height: 6),
                  _chipRow(chips),
                ],
              ],
            ),
          ),
          if (stepper != null) ...[
            const SizedBox(width: 16),
            Text(
              ownedLabel,
              style: const TextStyle(fontSize: 13, color: RdColors.text3),
            ),
            const SizedBox(width: 12),
            stepper,
          ],
        ],
      ),
    );
  }
}

/// Phone app bar of the detail page: back, small icon and the name.
class _CompactDetailBar extends StatelessWidget {
  const _CompactDetailBar({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    required this.item,
  });

  final String title;
  final String backTooltip;
  final VoidCallback onBack;
  final ItemEntry? item;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    return Container(
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 16),
            child: Row(
              children: [
                RdIconButton(
                  icon: Icons.chevron_left,
                  tooltip: backTooltip,
                  filled: false,
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                if (item != null) ...[
                  ExcludeSemantics(
                    child: ItemIcon(
                      itemId: item.itemId,
                      iconId: item.iconId,
                      name: item.name,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdText.mobileTitle,
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

/// Phone summary card: tier / kind chips and the owned-count stepper.
class _CompactSummaryCard extends StatelessWidget {
  const _CompactSummaryCard({
    required this.chips,
    required this.ownedLabel,
    required this.stepper,
  });

  final List<String> chips;
  final String ownedLabel;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chipRow(chips),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  ownedLabel,
                  style: const TextStyle(fontSize: 13, color: RdColors.text3),
                ),
              ),
              stepper,
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder of the body until the item is resolved (local data, usually
/// a single frame).
class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const RdPulse(
      child: RdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSkeleton(height: 16, widthFactor: 0.3, color: RdColors.white8),
            SizedBox(height: 14),
            RdSkeleton(height: 12, widthFactor: 0.9, color: RdColors.white5),
            SizedBox(height: 8),
            RdSkeleton(height: 12, widthFactor: 0.7, color: RdColors.white5),
          ],
        ),
      ),
    );
  }
}

/// 56px placeholder row of the recipe and drop lists.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: RdColors.surface3,
        borderRadius: BorderRadius.circular(RdRadii.control),
      ),
      child: const Row(
        children: [
          RdSkeleton(width: 64, height: 14),
          SizedBox(width: 14),
          Expanded(child: RdSkeleton(height: 10, widthFactor: 0.6)),
          SizedBox(width: 14),
          RdSkeleton(width: 52, height: 14),
        ],
      ),
    );
  }
}

/// Recipe ingredient row; tapping it opens that ingredient's detail page.
class _FormulaCostRow extends StatelessWidget {
  const _FormulaCostRow({
    required this.cost,
    required this.meta,
    required this.metaLabel,
    required this.openLabel,
    required this.onOpen,
  });

  final FormulaCost cost;
  final ItemEntry? meta;
  final String metaLabel;
  final String openLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final name = (meta?.name.isNotEmpty ?? false) ? meta!.name : cost.id;
    final radius = BorderRadius.circular(RdRadii.control);
    return Semantics(
      link: onOpen != null,
      label: onOpen == null ? null : openLabel,
      child: Material(
        color: RdColors.surface3,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: onOpen,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: ItemIcon(
                    itemId: cost.id,
                    iconId: meta?.iconId,
                    name: name,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: RdColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  metaLabel,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: RdColors.text3),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '×${formatJsNumber(cost.count)}',
                    textAlign: TextAlign.right,
                    style: RdText.mono(fontSize: 14),
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

/// One Penguin Stats stage: code, a drop-rate bar, the rate and the
/// sample count.
class _PenguinDropRow extends StatelessWidget {
  const _PenguinDropRow({
    required this.compact,
    required this.stageLabel,
    required this.dropRate,
    required this.barFraction,
    required this.rateLabel,
    required this.times,
    required this.timesLabel,
  });

  final bool compact;
  final String stageLabel;
  final double dropRate;

  /// Bar length relative to the best drop rate of the list (real rates are
  /// a few percent, so an absolute bar would be a dot).
  final double barFraction;
  final String rateLabel;
  final int times;
  final String timesLabel;

  @override
  Widget build(BuildContext context) {
    final rate = '${(dropRate * 100).toStringAsFixed(2)}%';
    final fill = barFraction.clamp(0.0, 1.0);
    return Semantics(
      label: '$stageLabel, $rateLabel $rate, $timesLabel $times',
      excludeSemantics: true,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: RdColors.surface3,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 72 : 96,
              child: Text(
                stageLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: RdColors.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: RdColors.white5,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RdColors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 64,
              child: Text(
                rate,
                textAlign: TextAlign.right,
                style: RdText.mono(fontSize: 14),
              ),
            ),
            SizedBox(
              width: compact ? 52 : 64,
              child: Text(
                '$times',
                textAlign: TextAlign.right,
                style: RdText.mono(fontSize: 12, color: RdColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
