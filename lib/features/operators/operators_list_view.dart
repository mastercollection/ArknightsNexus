import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operators_common.dart';
import 'operators_list_controller.dart';

const _loadingCardCount = 12;

/// Tile heights (fixed so the grid can lay out lazily).
/// Phone: 10 + 76 portrait + 6 + stars 14 + 6 + name 18 + 12 + borders.
const _compactTileExtent = 10 + 76 + 6 + 14 + 6 + 18 + 12 + 2.0;

/// PC: 12 + 80 portrait + 8 + name 20 + 6 + profession 16 + 14 + borders.
const _wideTileExtent = 12 + 80 + 8 + 20 + 6 + 16 + 14 + 2.0;

/// Height of the "more" footer that also acts as the paging sentinel.
const _sentinelHeight = 48.0;

/// Scrollable operator grid with the list states (loading skeletons, error,
/// empty) and `useInfiniteSlice` paging: 36 tiles first, then 24 more each
/// time the footer comes within 240px of the viewport.
class OperatorsGridView extends ConsumerStatefulWidget {
  const OperatorsGridView({
    required this.compact,
    required this.onSelect,
    this.selectedId,
    this.padding = EdgeInsets.zero,
    this.onScroll,
    super.key,
  });

  /// Phone tiles (stars under the portrait) instead of the PC tiles.
  final bool compact;
  final ValueChanged<OperatorSummary> onSelect;
  final String? selectedId;
  final EdgeInsets padding;

  /// Scroll offset listener (condensing header).
  final ValueChanged<double>? onScroll;

  @override
  ConsumerState<OperatorsGridView> createState() => _OperatorsGridViewState();
}

class _OperatorsGridViewState extends ConsumerState<OperatorsGridView> {
  late final ScrollController _scrollController;
  late final OperatorsListController _list;

  @override
  void initState() {
    super.initState();
    _list = ref.read(operatorsListControllerProvider);
    _scrollController =
        ScrollController(initialScrollOffset: _list.scrollOffset)
          ..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// IntersectionObserver with `rootMargin: 240px` on the footer sentinel.
  bool get _sentinelNearViewport {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    return position.extentAfter - _sentinelHeight <= 240;
  }

  void _handleScroll() {
    final list = ref.read(operatorsListControllerProvider);
    list.scrollOffset = _scrollController.position.pixels;
    if (list.hasMore && _sentinelNearViewport) {
      list.loadMore();
    }
    widget.onScroll?.call(_scrollController.position.pixels);
  }

  void _scheduleSentinelCheck(OperatorsListController list) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && list.hasMore && _sentinelNearViewport) {
        list.loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final list = ref.watch(operatorsListControllerProvider);

    final List<Widget> slivers;
    if (list.errorMessage.isNotEmpty) {
      slivers = [
        SliverToBoxAdapter(
          child: RdStatePanel(
            kind: RdStateKind.error,
            title: i18n.t('operatorsList.states.errorTitle'),
            message: list.errorMessage,
          ),
        ),
      ];
    } else if (list.isLoading) {
      slivers = [
        SliverToBoxAdapter(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t('operatorsList.states.loadingTitle'),
                  style: TextStyle(
                    fontSize: widget.compact ? 16 : 17,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  i18n.t('operatorsList.states.loadingDescription'),
                  style: RdText.muted,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        _grid(
          _loadingCardCount,
          (context, index) => _LoadingTile(compact: widget.compact),
        ),
      ];
    } else if (list.operatorList.isNotEmpty) {
      _scheduleSentinelCheck(list);
      slivers = [
        _grid(
          list.visibleCount,
          (context, index) {
            final operator = list.operatorList[index];
            return OperatorTile(
              key: ValueKey('operator-tile-${operator.id}'),
              operator: operator,
              compact: widget.compact,
              selected: operator.id == widget.selectedId,
              professionLabel: i18n.profession(operator.profession),
              unreleasedLabel: operator.unreleasedSource == null
                  ? null
                  : unreleasedLabel(i18n, operator.unreleasedSource!),
              onTap: () => widget.onSelect(operator),
            );
          },
        ),
        if (list.hasMore)
          SliverToBoxAdapter(
            child: SizedBox(
              height: _sentinelHeight,
              child: Center(
                child: Text(
                  i18n.t('rd.operators.list.more'),
                  style: RdText.small,
                ),
              ),
            ),
          ),
      ];
    } else {
      slivers = [
        SliverToBoxAdapter(
          child: RdStatePanel(
            kind: RdStateKind.empty,
            title: i18n.t('operatorsList.states.emptyTitle'),
            message: i18n.t('operatorsList.states.emptyDescription'),
          ),
        ),
      ];
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }

  /// `repeat(auto-fill, minmax(112px, 1fr))` (PC) / three columns on phones.
  Widget _grid(int count, NullableIndexedWidgetBuilder builder) {
    final gap = widget.compact ? 10.0 : 12.0;
    final minTile = widget.compact ? 100.0 : 112.0;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = rdAutoColumns(width, minTile, gap: gap, min: 2);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent:
                widget.compact ? _compactTileExtent : _wideTileExtent,
          ),
          delegate: SliverChildBuilderDelegate(builder, childCount: count),
        );
      },
    );
  }
}

/// Operator card of the list grid.
class OperatorTile extends StatefulWidget {
  const OperatorTile({
    required this.operator,
    required this.compact,
    required this.selected,
    required this.professionLabel,
    required this.onTap,
    this.unreleasedLabel,
    super.key,
  });

  final OperatorSummary operator;
  final bool compact;
  final bool selected;
  final String professionLabel;
  final VoidCallback onTap;

  /// Badge text of an operator the region has not released yet.
  final String? unreleasedLabel;

  @override
  State<OperatorTile> createState() => _OperatorTileState();
}

class _OperatorTileState extends State<OperatorTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final operator = widget.operator;
    final stars = '★' * operator.rarity;
    final selected = widget.selected;
    final borderColor = selected
        ? const Color(0xB385B6FF)
        : _hovered
            ? const Color(0x5985B6FF)
            : RdColors.line2;
    final background = widget.compact
        ? RdColors.card
        : selected
            ? const Color(0xFF12203A)
            : opPanelFill;
    final radius = widget.compact ? 16.0 : 22.0;
    final unreleased = widget.unreleasedLabel;
    // Over the bottom edge of the portrait, so the tile keeps its height.
    final badge = unreleased == null
        ? null
        : Positioned(
            left: -6,
            right: -6,
            bottom: -4,
            child: Center(
              child: UnreleasedBadge(
                key: ValueKey('operator-unreleased-${operator.id}'),
                label: unreleased,
                small: true,
              ),
            ),
          );

    final name = Text(
      operator.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      strutStyle: StrutStyle(
        fontSize: widget.compact ? 13 : 14,
        height: widget.compact ? 18 / 13 : 20 / 14,
        forceStrutHeight: true,
      ),
      style: TextStyle(
        fontSize: widget.compact ? 13 : 14,
        fontWeight: FontWeight.w700,
        letterSpacing: widget.compact ? 0 : -0.28,
        color: RdColors.text,
      ),
    );

    final Widget content;
    if (widget.compact) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        child: Column(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RdPortrait(
                    charId: operator.id,
                    name: operator.name,
                    size: 76,
                    radius: 18,
                  ),
                  if (badge != null) badge,
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 14,
              child: Text(
                stars,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  letterSpacing: 0.4,
                  color: RdColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            name,
          ],
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RdPortrait(
                    charId: operator.id,
                    name: operator.name,
                    size: 80,
                    radius: 22,
                  ),
                  Positioned(
                    top: 6,
                    left: -20,
                    right: -20,
                    child: Text(
                      stars,
                      textAlign: TextAlign.center,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1,
                        letterSpacing: 0.2,
                        color: RdColors.gold,
                        shadows: [Shadow(blurRadius: 4)],
                      ),
                    ),
                  ),
                  if (badge != null) badge,
                ],
              ),
            ),
            const SizedBox(height: 8),
            name,
            const SizedBox(height: 6),
            Text(
              widget.professionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              strutStyle: const StrutStyle(
                fontSize: 12,
                height: 16 / 12,
                forceStrutHeight: true,
              ),
              style: const TextStyle(fontSize: 12, color: RdColors.muted),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: [
        operator.name,
        stars,
        widget.professionLabel,
        if (unreleased != null) unreleased,
      ].join(', '),
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: widget.onTap, child: content),
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 76.0 : 80.0;
    return Container(
      padding: EdgeInsets.fromLTRB(6, compact ? 10 : 14, 6, 14),
      decoration: BoxDecoration(
        color: compact ? RdColors.card : opPanelFill,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(color: RdColors.line2),
      ),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RdColors.portrait,
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
            ),
            child: const RdPulse(
              child: RdSkeleton(
                width: 44,
                height: 44,
                radius: 16,
                color: RdColors.soft,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const RdPulse(child: RdSkeleton(height: 12, widthFactor: 0.72)),
        ],
      ),
    );
  }
}
