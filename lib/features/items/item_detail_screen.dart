import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../domain/penguin_matrix.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../ui/nexus_ui.dart' show ItemIcon;
import '../../ui/redesign/rd_widgets.dart';
import 'item_format.dart';

enum PenguinSortKey { dropRate, sampleCount }

/// Port of `src/pages/items/[itemId].vue`, laid out after the redesign
/// canvas (`DesktopItemDetail` / `MobileItemDetail`): header with the item
/// icon, the building recipe card next to the Penguin Stats drops on wide
/// screens, stacked on phones.
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
  const _LinkedFormula(this.formulaId, this.costs);

  final String formulaId;
  final List<FormulaCost> costs;
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  ItemEntry? _item;
  bool _isLoading = true;
  String _errorMessage = '';
  List<PenguinMatrixEntry> _penguinDrops = const [];
  String _penguinErrorMessage = '';
  bool _isPenguinLoading = false;
  BuildingFormulaBundle _formulas = const BuildingFormulaBundle();
  String _buildingFormulaErrorMessage = '';
  Map<String, ItemEntry> _allItems = const {};
  Map<String, String> _stageCodeMap = const {};
  PenguinServer _penguinServer = PenguinServer.cn;
  PenguinSortKey _penguinSortKey = PenguinSortKey.dropRate;
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

  /// `loadItem`: the whole page stays in its loading state until the item,
  /// stage codes, item metadata, formulas, and Penguin drops are resolved.
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
      if (item != null) {
        final stageCodes = await ref
            .read(regionSyncServiceProvider)
            .getRegionStageCodes(region);
        if (stale()) {
          return;
        }
        var formulas = const BuildingFormulaBundle();
        var formulaError = '';
        try {
          formulas = await itemService.listBuildingFormulas(region);
        } catch (error) {
          formulaError = '$error';
        }
        if (stale()) {
          return;
        }
        setState(() {
          _item = item;
          _stageCodeMap = stageCodes;
          _allItems = {for (final entry in items) entry.itemId: entry};
          _formulas = formulas;
          _buildingFormulaErrorMessage = formulaError;
        });
        await _loadPenguinDrops(item.itemId);
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('item detail load failed', error, stackTrace);
      if (!stale()) {
        setState(() => _errorMessage = '$error');
      }
    } finally {
      if (!stale()) {
        setState(() => _isLoading = false);
      }
    }
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
        linked.add(_LinkedFormula(product.formulaId, costs));
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

    final header = RdPageHeader(
      title: item?.name ?? i18n.t('itemsDetail.topBar.title'),
      compactTitleStyle: RdText.mobileTitle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      backTooltip: i18n.t('rd.items.backToList'),
      onBack: _backToList,
      leading: item == null
          ? null
          : ExcludeSemantics(
              child: ItemIcon(
                itemId: item.itemId,
                iconId: item.iconId,
                name: item.name,
                size: 44,
              ),
            ),
    );

    final Widget body;
    if (_isLoading) {
      body = Semantics(
        label: i18n.t('itemsPage.states.loading'),
        child: const _DetailLoading(),
      );
    } else if (_errorMessage.isNotEmpty) {
      body = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('itemsDetail.states.error'),
        message: _errorMessage,
      );
    } else if (item == null) {
      body = RdStatePanel(
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
      );
    } else {
      body = _buildDetail(i18n, item, compact);
    }

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) header,
          Expanded(
            child: ListView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                  : rdPagePadding(context),
              children: [
                if (!compact) ...[header, const SizedBox(height: 18)],
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(NexusI18n i18n, ItemEntry item, bool compact) {
    final recipe = _buildRecipeSection(i18n, compact);
    final penguin = _buildPenguinSection(i18n, compact);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The item id is a development aid (`import.meta.env.DEV`).
        if (kDebugMode) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: item.itemId,
                  style: RdText.mono(
                    fontSize: 12,
                    color: const Color(0xFF8A96AD),
                  ),
                ),
                TextSpan(text: ' · ${i18n.t('rd.items.devOnly')}'),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A96AD)),
          ),
          SizedBox(height: compact ? 14 : 18),
        ],
        if (recipe == null)
          penguin
        else if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [recipe, const SizedBox(height: 14), penguin],
          )
        else
          // `flex: 1 1 340px` recipe card next to `flex: 2 1 480px` drops,
          // wrapping onto two rows when both minimums do not fit.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340 + 18 + 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [recipe, const SizedBox(height: 18), penguin],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: recipe),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: penguin),
                ],
              );
            },
          ),
      ],
    );
  }

  /// Building recipe card; hidden unless a linked formula has costs or the
  /// formula load failed.
  Widget? _buildRecipeSection(NexusI18n i18n, bool compact) {
    final linked = _linkedBuildingFormulas;
    if (linked.isEmpty && _buildingFormulaErrorMessage.isEmpty) {
      return null;
    }
    final gap = compact ? 10.0 : 12.0;
    return RdCard.tile(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RdHeading(
            i18n.t('itemsDetail.sections.buildingRecipes'),
            fontSize: 16,
            letterSpacing: -0.32,
          ),
          SizedBox(height: gap),
          if (_buildingFormulaErrorMessage.isNotEmpty)
            RdStatePanel(
              kind: RdStateKind.error,
              layout: RdStateLayout.left,
              surface: RdStateSurface.inner,
              title: i18n.t('itemsDetail.states.buildingFormulaError'),
              message: _buildingFormulaErrorMessage,
            )
          else
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
                    compact: compact,
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
    );
  }

  Widget _buildPenguinSection(NexusI18n i18n, bool compact) {
    final Widget body;
    if (_isPenguinLoading) {
      body = RdPulse(
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: const RdCard.tile(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RdSkeleton(
                        height: 16,
                        widthFactor: 0.42,
                        color: RdColors.white8,
                      ),
                      SizedBox(height: 8),
                      RdSkeleton(
                        height: 12,
                        widthFactor: 0.68,
                        color: RdColors.white5,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (_penguinErrorMessage.isNotEmpty) {
      body = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        surface: RdStateSurface.inner,
        title: i18n.t('itemsDetail.states.penguinError'),
        message: _penguinErrorMessage,
        color: RdColors.card,
      );
    } else if (_penguinDrops.isNotEmpty) {
      final cards = [
        for (final entry in _sortedPenguinDrops)
          _PenguinDropCard(
            key: ValueKey(
              '${entry.stageId}:${entry.start ?? 'none'}:${entry.end ?? 'none'}',
            ),
            compact: compact,
            stageLabel: penguinStageLabel(entry.stageId, _stageCodeMap),
            rate: '${i18n.t('itemsDetail.labels.dropRate')} '
                '${(entry.dropRate * 100).toStringAsFixed(2)}%',
            times: '${i18n.t('itemsDetail.labels.sampleCount')} ${entry.times}',
            source: i18n.t(
              'itemsDetail.labels.dropSourcePenguin',
              {'server': _penguinServer.value},
            ),
          ),
      ];
      body = compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, card) in cards.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: card,
                  ),
              ],
            )
          : RdAutoGrid(
              minTileWidth: 260,
              gap: 8,
              equalHeight: true,
              children: cards,
            );
    } else {
      body = Text(
        i18n.t('itemsDetail.states.noPenguinDrops'),
        style: const TextStyle(fontSize: 14, color: RdColors.secondary2),
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
      width: compact ? 76 : 120,
      height: compact ? 44 : 36,
      value: _penguinServer,
      options: [
        for (final server in ItemDetailScreen.penguinServers)
          RdSelectOption(server, server.value),
      ],
      onChanged: _setPenguinServer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            RdHeading(
              i18n.t('itemsDetail.sections.penguinDrops'),
              fontSize: 16,
              letterSpacing: -0.32,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [sortSelect, const SizedBox(width: 8), serverSelect],
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 12),
        body,
      ],
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const RdPulse(
      child: RdCard.tile(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RdSkeleton(
                width: 84,
                height: 84,
                radius: 22,
                color: RdColors.soft,
              ),
            ),
            SizedBox(height: 12),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.48,
                child: RdSkeleton(height: 20, color: RdColors.white8),
              ),
            ),
            SizedBox(height: 12),
            RdSkeleton(height: 72, radius: 18, color: RdColors.soft2),
          ],
        ),
      ),
    );
  }
}

/// Recipe ingredient row; tapping it opens that ingredient's detail page.
class _FormulaCostRow extends StatelessWidget {
  const _FormulaCostRow({
    required this.cost,
    required this.meta,
    required this.compact,
    required this.openLabel,
    required this.onOpen,
  });

  final FormulaCost cost;
  final ItemEntry? meta;
  final bool compact;
  final String openLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final name = (meta?.name.isNotEmpty ?? false) ? meta!.name : cost.id;
    final radius = BorderRadius.circular(RdRadii.inner);
    return Semantics(
      link: onOpen != null,
      label: onOpen == null ? null : openLabel,
      child: Material(
        color: const Color(0x09FFFFFF),
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: RdColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cost.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: RdColors.secondary2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                Text(
                  'x${formatJsNumber(cost.count)}',
                  style: RdText.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: RdColors.secondary,
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

class _PenguinDropCard extends StatelessWidget {
  const _PenguinDropCard({
    required this.compact,
    required this.stageLabel,
    required this.rate,
    required this.times,
    required this.source,
    super.key,
  });

  final bool compact;
  final String stageLabel;
  final String rate;
  final String times;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0x09FFFFFF),
        borderRadius: BorderRadius.circular(RdRadii.inner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: RdColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DropChip(label: rate, mono: true),
              _DropChip(label: times, mono: true),
              _DropChip(
                label: source,
                color: RdColors.goldFill,
                textColor: RdColors.warnText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({
    required this.label,
    this.mono = false,
    this.color = RdColors.blueFill,
    this.textColor = RdColors.blueText,
  });

  final String label;
  final bool mono;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RdRadii.pill),
      ),
      child: Text(
        label,
        style: mono
            ? RdText.mono(fontSize: 12, color: textColor)
            : TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }
}
