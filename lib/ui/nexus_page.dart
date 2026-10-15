import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'nexus_scrollbar.dart';
import 'nexus_surfaces.dart';
import 'nexus_tokens.dart';

enum NexusBackdrop {
  /// `layouts/home.vue`: radial blue glow at the top + vertical gradient.
  home,

  /// `layouts/operators.vue` (default for detail pages): vertical gradient.
  standard,
}

/// Page scaffold equivalent to the Vue layouts: gradient backdrop, a sticky
/// [topBar], and content constrained by `shell-wrap` (max 72rem, 16px gutter).
///
/// Content is given as slivers so long lists stay lazy. Use [NexusPage.list]
/// for plain widget lists, which get the `page-grid` gap (16, 20 from md).
class NexusPage extends StatefulWidget {
  const NexusPage({
    required this.slivers,
    this.topBar,
    this.backdrop = NexusBackdrop.standard,
    this.controller,
    this.onRefresh,
    this.stickyTopBar,
    super.key,
  });

  NexusPage.list({
    required List<Widget> children,
    Widget? topBar,
    NexusBackdrop backdrop = NexusBackdrop.standard,
    ScrollController? controller,
    Future<void> Function()? onRefresh,
    bool? stickyTopBar,
    Key? key,
  }) : this(
          slivers: [NexusSliverGap(children: children)],
          topBar: topBar,
          backdrop: backdrop,
          controller: controller,
          onRefresh: onRefresh,
          stickyTopBar: stickyTopBar,
          key: key,
        );

  final List<Widget> slivers;
  final Widget? topBar;
  final NexusBackdrop backdrop;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  /// Whether [topBar] stays pinned while scrolling. Defaults to the Vue
  /// layout's actual behaviour: `layouts/home.vue` keeps TopBar.vue sticky,
  /// but `layouts/operators.vue` wraps pages in `overflow-x-hidden`, which
  /// makes `main` the sticky container, so there the bar scrolls away.
  final bool? stickyTopBar;

  bool get _sticky => stickyTopBar ?? backdrop == NexusBackdrop.home;

  static double gutterFor(double width) {
    return math.max(16, (width - NexusBreakpoints.shellMaxWidth) / 2 + 16);
  }

  static double pageGapFor(double width) {
    return width >= NexusBreakpoints.md ? 20 : 16;
  }

  @override
  State<NexusPage> createState() => _NexusPageState();
}

class _NexusPageState extends State<NexusPage> {
  /// Measured height of the sticky top bar; content starts below it and
  /// scrolls underneath (TopBar.vue is `sticky top-0` with backdrop blur).
  double _topBarHeight = 0;

  /// TopBar.vue sits below `main`'s 12px padding plus its own 12px, then
  /// sticks with only its own 12px once the page has scrolled past.
  static const _stickyTop = 12.0;
  double _scrollPull = 0;

  ScrollController? _ownController;

  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void dispose() {
    _ownController?.dispose();
    _metrics.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      final pull = notification.metrics.pixels.clamp(0.0, _stickyTop);
      if (pull != _scrollPull) {
        setState(() => _scrollPull = pull);
      }
    }
    return false;
  }

  void _onTopBarSize(Size size) {
    if (size.height != _topBarHeight) {
      setState(() => _topBarHeight = size.height);
    }
  }

  /// Latest metrics of the page scroll view; the layout gradient spans the
  /// whole document (as the Vue layout div does) and scrolls with it.
  final _metrics = ValueNotifier<ScrollMetrics?>(null);

  bool _trackMetrics(ScrollMetrics metrics, int depth) {
    if (depth == 0 && metrics.axis == Axis.vertical) {
      _metrics.value = metrics;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topBar = widget.topBar;
    final sticky = widget._sticky;
    final backdrop = widget.backdrop;
    final controller = _controller;
    final onRefresh = widget.onRefresh;
    final slivers = widget.slivers;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: NexusColors.app,
      body: SafeArea(
        bottom: false,
        child: NexusClassicScrollbar(
          controller: controller,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = NexusPage.gutterFor(constraints.maxWidth);
              final gap = NexusPage.pageGapFor(constraints.maxWidth);
              Widget scroll = CustomScrollView(
                controller: controller,
                physics: onRefresh == null
                    ? null
                    : const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      topBar == null
                          ? 12
                          : sticky
                              ? 2 * _stickyTop + _topBarHeight + gap
                              : 2 * _stickyTop,
                      gutter,
                      // `main` pb-[4.5rem] plus `page-grid` pb-10 (md: pb-12).
                      bottomInset + 72 + (gap == 20 ? 48 : 40),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (topBar != null && !sticky) ...[
                          SliverToBoxAdapter(child: topBar),
                          SliverToBoxAdapter(child: SizedBox(height: gap)),
                        ],
                        ...slivers,
                      ],
                    ),
                  ),
                ],
              );
              if (onRefresh != null) {
                scroll = RefreshIndicator(
                  onRefresh: onRefresh,
                  child: scroll,
                );
              }
              scroll = NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) => _trackMetrics(n.metrics, n.depth),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    _trackMetrics(n.metrics, n.depth);
                    return sticky && topBar != null && _onScroll(n);
                  },
                  child: scroll,
                ),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BackdropPainter(_metrics, backdrop),
                      ),
                    ),
                  ),
                  Positioned.fill(child: scroll),
                  if (topBar != null && sticky)
                    Positioned(
                      left: gutter,
                      right: gutter,
                      top: 2 * _stickyTop - _scrollPull,
                      child: _SizeReporter(
                        onSize: _onTopBarSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: topBar,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The Vue layout backgrounds: a vertical gradient (plus a radial glow at the
/// top for `layouts/home.vue`) sized to the whole document, not the viewport.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.metrics, this.backdrop) : super(repaint: metrics);

  final ValueNotifier<ScrollMetrics?> metrics;
  final NexusBackdrop backdrop;

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics.value;
    final scrolled = m == null ? 0.0 : m.pixels - m.minScrollExtent;
    final docHeight = m == null
        ? size.height
        : math.max(
            size.height,
            m.maxScrollExtent - m.minScrollExtent + m.viewportDimension,
          );
    final doc = Rect.fromLTWH(0, -scrolled, size.width, docHeight);
    final home = backdrop == NexusBackdrop.home;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          doc.topCenter,
          doc.bottomCenter,
          home
              ? const [NexusColors.app, NexusColors.shell]
              : const [NexusColors.app, Color(0xFF0A1020)],
        ),
    );
    if (home) {
      // `radial-gradient(circle at top, ... transparent 22%)`: a circle
      // reaching the farthest corner.
      final radius = math.sqrt(
        doc.width * doc.width / 4 + doc.height * doc.height,
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            doc.topCenter,
            radius,
            const [Color(0x295CB4FF), Color(0x005CB4FF)],
            const [0, 0.22],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.metrics != metrics || oldDelegate.backdrop != backdrop;
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _reported) {
      _reported = size;
      final reported = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
    }
  }
}

/// Sliver that lays out [children] vertically with the page-grid gap.
class NexusSliverGap extends StatelessWidget {
  const NexusSliverGap({required this.children, this.gap, super.key});

  final List<Widget> children;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final spacing = gap ?? NexusPage.pageGapFor(width);
    return SliverList.separated(
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (context, index) => SizedBox(height: spacing),
    );
  }
}

/// `TopBar.vue`: sticky glass header with left/title/right/support slots.
class NexusTopBar extends StatelessWidget {
  const NexusTopBar({
    this.left,
    this.title,
    this.subtitle,
    this.description,
    this.right = const [],
    this.support,
    super.key,
  });

  final Widget? left;
  final String? title;
  final String? subtitle;
  final String? description;
  final List<Widget> right;
  final Widget? support;

  @override
  Widget build(BuildContext context) {
    final hasHeading = title != null || description != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // `top-bar-shell` is a <div>: no border-style without a CSS reset.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2080C18), Color(0xC7080C18)],
        ),
      ),
      // `shadow-glass`: inset top highlight.
      child: CustomPaint(
        painter: const InsetTopHighlightPainter(radius: 22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (left != null) ...[
                    // Without a heading the left slot may shrink (e.g. the home
                    // brand on phones) instead of overflowing the right slot.
                    if (hasHeading)
                      left!
                    else
                      Expanded(
                        child:
                            Align(alignment: Alignment.centerLeft, child: left),
                      ),
                    const SizedBox(width: 12),
                  ],
                  if (hasHeading)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (title != null)
                                Text(
                                  title!,
                                  style: const TextStyle(
                                    fontSize: 16.8,
                                    height: 1,
                                    leadingDistribution:
                                        TextLeadingDistribution.even,
                                    fontWeight: FontWeight.w700,
                                    color: NexusColors.text,
                                  ),
                                ),
                              if (subtitle != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x246890FF),
                                    borderRadius:
                                        BorderRadius.circular(NexusRadii.pill),
                                  ),
                                  child: Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      fontSize: 12.16,
                                      height: 1,
                                      color: Color(0xFFD8E5FF),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              description!,
                              // Chromium rounds font ascent/descent: 16 + 4.
                              style: const TextStyle(
                                fontSize: 13.44,
                                height: 20 / 13.44,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                                color: NexusColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (left == null)
                    const Spacer(),
                  if (right.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    for (var i = 0; i < right.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      right[i],
                    ],
                  ],
                ],
              ),
              if (support != null) ...[const SizedBox(height: 12), support!],
            ],
          ),
        ),
      ),
    );
  }
}
