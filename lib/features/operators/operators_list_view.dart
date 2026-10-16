import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../shared/number_format.dart';
import 'operators_common.dart';
import 'operators_list_controller.dart';

const _loadingCardCount = 12;

/// Tile heights (fixed so the grid can lay out lazily): padding, portrait,
/// then name 18, stars 12 and profession 16 with 5px gaps, and borders.
/// Phone: 10 + 64 portrait + ... + 10.
const _compactTileExtent = 10 + 64 + 5 + 18 + 5 + 12 + 5 + 16 + 10 + 2.0;

/// PC: 12 + 72 portrait + ... + 10.
const _wideTileExtent = 12 + 72 + 5 + 18 + 5 + 12 + 5 + 16 + 10 + 2.0;

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
    } else if (list.operatorList.isNotEmpty || list.unreleasedList.isNotEmpty) {
      _scheduleSentinelCheck(list);
      slivers = [
        if (list.unreleasedList.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: list.operatorList.isEmpty
                  ? 0
                  : widget.compact
                      ? 12
                      : 14,
            ),
            sliver: SliverToBoxAdapter(
              child: UnreleasedStrip(
                operators: list.unreleasedList,
                expanded: list.unreleasedExpanded,
                compact: widget.compact,
                selectedId: widget.selectedId,
                onToggle: list.toggleUnreleasedExpanded,
                onSelect: widget.onSelect,
              ),
            ),
          ),
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
    final gap = widget.compact ? 8.0 : 10.0;
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

/// Operator card of the list grid: portrait, name, rarity and profession.
class OperatorTile extends StatefulWidget {
  const OperatorTile({
    required this.operator,
    required this.compact,
    required this.selected,
    required this.professionLabel,
    required this.onTap,
    super.key,
  });

  final OperatorSummary operator;
  final bool compact;
  final bool selected;
  final String professionLabel;
  final VoidCallback onTap;

  @override
  State<OperatorTile> createState() => _OperatorTileState();
}

class _OperatorTileState extends State<OperatorTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final operator = widget.operator;
    final compact = widget.compact;
    final stars = '★' * operator.rarity;
    final selected = widget.selected;
    final borderColor =
        selected || _hovered ? RdColors.accentLine : RdColors.hairline;
    final background = selected ? RdColors.accentSoft : RdColors.surface2;
    final portrait = compact ? 64.0 : 72.0;

    Widget line(String text, double size, double lineHeight, TextStyle style) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        strutStyle: StrutStyle(
          fontSize: size,
          height: lineHeight / size,
          forceStrutHeight: true,
        ),
        style: style.copyWith(fontSize: size),
      );
    }

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 10 : 12,
        compact ? 6 : 8,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RdPortrait(
              charId: operator.id,
              name: operator.name,
              size: portrait,
              radius: RdRadii.control,
            ),
          ),
          const SizedBox(height: 5),
          line(
            operator.name,
            13,
            18,
            const TextStyle(fontWeight: FontWeight.w600, color: RdColors.text),
          ),
          const SizedBox(height: 5),
          line(
            stars,
            11,
            12,
            const TextStyle(letterSpacing: -0.5, color: RdColors.rarity),
          ),
          const SizedBox(height: 5),
          line(
            widget.professionLabel,
            12,
            16,
            const TextStyle(color: RdColors.text3),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: [operator.name, stars, widget.professionLabel].join(', '),
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.card),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: widget.onTap, child: content),
        ),
      ),
    );
  }
}

/// The operators the selected region has not released yet, kept out of the
/// grid: one collapsible card above it ("미실장 17명 · CN 공식 데이터")
/// whose expanded body is a horizontal row of small tiles.
class UnreleasedStrip extends ConsumerStatefulWidget {
  const UnreleasedStrip({
    required this.operators,
    required this.expanded,
    required this.compact,
    required this.onToggle,
    required this.onSelect,
    this.selectedId,
    super.key,
  });

  final List<OperatorSummary> operators;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggle;
  final ValueChanged<OperatorSummary> onSelect;
  final String? selectedId;

  @override
  ConsumerState<UnreleasedStrip> createState() => _UnreleasedStripState();
}

class _UnreleasedStripState extends ConsumerState<UnreleasedStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A plain mouse wheel scrolls the row sideways (it has no vertical
  /// extent of its own) instead of the list around it.
  void _handleWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) {
      return;
    }
    final delta =
        event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _scroll.jumpTo(
        (position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final operators = widget.operators;
    final compact = widget.compact;
    final expanded = widget.expanded;
    final sources = {
      for (final operator in operators)
        operator.unreleasedSource!.toUpperCase(),
    }.join(' · ');
    final title = i18n.t('rd.operators.strip.title', {
      'count': formatWholeNumber(operators.length),
    });
    final peek = [
      for (final operator in operators.take(5)) operator,
    ];

    final header = Semantics(
      button: true,
      expanded: expanded,
      label: '$title, $sources',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('operators-unreleased-strip-toggle'),
        borderRadius: BorderRadius.circular(RdRadii.card),
        onTap: widget.onToggle,
        child: SizedBox(
          height: compact ? 48 : 48,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
            child: Row(
              children: [
                UnreleasedBadge(label: sources),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RdColors.text,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '· ${i18n.t('rd.operators.strip.source', {
                          'source': sources,
                        })}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: RdColors.text3),
                  ),
                ),
                if (!expanded && !compact) ...[
                  const SizedBox(width: 8),
                  _PortraitPeek(operators: peek),
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: RdColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final portrait = compact ? 52.0 : 56.0;
    final tileWidth = compact ? 60.0 : 68.0;
    final row = Listener(
      onPointerSignal: _handleWheel,
      child: SizedBox(
        // Portrait, the badge hanging 4px below it, gap and the name line.
        height: portrait + 4 + 4 + 18,
        child: ListView.separated(
          key: const Key('operators-unreleased-strip'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          itemCount: operators.length,
          separatorBuilder: (context, index) =>
              SizedBox(width: compact ? 8 : 10),
          itemBuilder: (context, index) {
            final operator = operators[index];
            return _UnreleasedTile(
              key: ValueKey('operator-tile-${operator.id}'),
              operator: operator,
              width: tileWidth,
              portrait: portrait,
              selected: operator.id == widget.selectedId,
              label: [
                operator.name,
                '★' * operator.rarity,
                i18n.profession(operator.profession),
                unreleasedLabel(i18n, operator.unreleasedSource!),
              ].join(', '),
              onTap: () => widget.onSelect(operator),
            );
          },
        ),
      ),
    );

    return Semantics(
      container: true,
      child: Material(
        color: RdColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.card),
          side: const BorderSide(color: RdColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (expanded)
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 12 : 14, top: 2),
                child: row,
              ),
          ],
        ),
      ),
    );
  }
}

/// Up to five overlapping portraits on the collapsed strip.
class _PortraitPeek extends StatelessWidget {
  const _PortraitPeek({required this.operators});

  final List<OperatorSummary> operators;

  static const _size = 26.0;
  static const _step = 20.0;

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: SizedBox(
        width: _size + (operators.length - 1) * _step + 4,
        height: _size + 4,
        child: Stack(
          children: [
            for (final (i, operator) in operators.indexed)
              Positioned(
                left: i * _step,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: RdColors.surface2,
                    borderRadius: BorderRadius.circular(RdRadii.chip + 2),
                  ),
                  child: RdPortrait(
                    charId: operator.id,
                    name: operator.name,
                    size: _size,
                    radius: RdRadii.chip,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small tile of the unreleased strip: portrait with the source badge and
/// the name under it.
class _UnreleasedTile extends StatefulWidget {
  const _UnreleasedTile({
    required this.operator,
    required this.width,
    required this.portrait,
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
  });

  final OperatorSummary operator;
  final double width;
  final double portrait;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<_UnreleasedTile> createState() => _UnreleasedTileState();
}

class _UnreleasedTileState extends State<_UnreleasedTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final operator = widget.operator;
    final highlight = widget.selected || _hovered;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            child: Column(
              children: [
                SizedBox(
                  width: widget.portrait,
                  height: widget.portrait,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(RdRadii.control),
                          border: Border.all(
                            color: highlight
                                ? RdColors.accentLine
                                : Colors.transparent,
                            width: widget.selected ? 2 : 1,
                          ),
                        ),
                        child: RdPortrait(
                          charId: operator.id,
                          name: operator.name,
                          size: widget.portrait,
                          radius: RdRadii.control,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: UnreleasedBadge(
                          key: ValueKey('operator-unreleased-${operator.id}'),
                          label: operator.unreleasedSource!.toUpperCase(),
                          small: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  operator.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  strutStyle: const StrutStyle(
                    fontSize: 12,
                    height: 18 / 12,
                    forceStrutHeight: true,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        widget.selected ? RdColors.accentText : RdColors.text,
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

class _LoadingTile extends StatelessWidget {
  const _LoadingTile({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 64.0 : 72.0;
    return Container(
      padding: EdgeInsets.fromLTRB(6, compact ? 10 : 14, 6, 14),
      decoration: BoxDecoration(
        color: RdColors.surface2,
        borderRadius: BorderRadius.circular(RdRadii.card),
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
              borderRadius: BorderRadius.circular(RdRadii.control),
            ),
            child: const RdPulse(
              child: RdSkeleton(
                width: 44,
                height: 44,
                radius: RdRadii.control,
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
