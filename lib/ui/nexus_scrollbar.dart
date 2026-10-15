import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Element Plus `lock-scroll`: while a drawer or dialog is open the body gets
/// `overflow: hidden` (plus padding for the scrollbar width), so the page
/// scrollbar disappears and its gutter shows the page background.
class NexusScrollLock {
  const NexusScrollLock._();

  static final ValueNotifier<int> depth = ValueNotifier(0);

  /// Keeps the page scrollbars hidden until [open]'s future completes.
  static Future<T> guard<T>(Future<T> Function() open) async {
    depth.value++;
    try {
      return await open();
    } finally {
      depth.value--;
    }
  }
}

/// Chromium's classic dark-scheme document scrollbar, as WebView2 draws it in
/// the Tauri app on Windows: a 15px opaque gutter that only appears (and only
/// takes layout width) while the page overflows.
///
/// [builder] lays out the scrollable page in the remaining width; the
/// scrollable must use [controller].
class NexusClassicScrollbar extends StatefulWidget {
  const NexusClassicScrollbar({
    required this.controller,
    required this.child,
    this.enabled,
    super.key,
  });

  final ScrollController controller;
  final Widget child;

  /// Defaults to Windows only (Android WebView uses overlay scrollbars).
  final bool? enabled;

  static const thickness = 15.0;

  static bool get platformDefault =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  State<NexusClassicScrollbar> createState() => _NexusClassicScrollbarState();
}

class _NexusClassicScrollbarState extends State<NexusClassicScrollbar> {
  bool _overflows = false;
  final _metrics = ValueNotifier<ScrollMetrics?>(null);

  bool get _enabled => widget.enabled ?? NexusClassicScrollbar.platformDefault;

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) {
      return false;
    }
    _metrics.value = metrics;
    final overflows = metrics.maxScrollExtent > metrics.minScrollExtent;
    if (overflows != _overflows) {
      // Defer: metrics notifications arrive during layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && overflows != _overflows) {
          setState(() => _overflows = overflows);
        }
      });
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _checkAfterLayout();
  }

  @override
  void didUpdateWidget(NexusClassicScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAfterLayout();
  }

  /// Static content may never send a metrics notification, so read the
  /// position once it has dimensions.
  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = widget.controller;
      if (mounted &&
          controller.hasClients &&
          controller.positions.length == 1 &&
          controller.position.hasContentDimensions) {
        _onMetrics(controller.position);
      }
    });
  }

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return widget.child;
    }
    final content = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: widget.child,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        if (_overflows)
          SizedBox(
            width: NexusClassicScrollbar.thickness,
            child: ValueListenableBuilder<int>(
              valueListenable: NexusScrollLock.depth,
              builder: (context, locked, track) => locked > 0
                  ? const ColoredBox(color: Color(0xFF050914))
                  : track!,
              child: _ScrollbarTrack(
                controller: widget.controller,
                metrics: _metrics,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollbarTrack extends StatefulWidget {
  const _ScrollbarTrack({required this.controller, required this.metrics});

  final ScrollController controller;
  final ValueNotifier<ScrollMetrics?> metrics;

  @override
  State<_ScrollbarTrack> createState() => _ScrollbarTrackState();
}

class _ScrollbarTrackState extends State<_ScrollbarTrack> {
  double? _dragStartY;
  double _dragStartPixels = 0;

  ScrollPosition? get _position =>
      widget.controller.hasClients ? widget.controller.position : null;

  void _jumpBy(double delta) {
    final position = _position;
    if (position == null) {
      return;
    }
    position.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _onTapDown(TapDownDetails details, double height) {
    final metrics = widget.metrics.value;
    if (metrics == null) {
      return;
    }
    final y = details.localPosition.dy;
    final geometry = _ThumbGeometry.of(metrics, height);
    if (y < _ThumbGeometry.button) {
      _jumpBy(-40);
    } else if (y > height - _ThumbGeometry.button) {
      _jumpBy(40);
    } else if (y < geometry.top) {
      _jumpBy(-metrics.viewportDimension * 0.875);
    } else if (y > geometry.bottom) {
      _jumpBy(metrics.viewportDimension * 0.875);
    }
  }

  void _onDragStart(DragStartDetails details, double height) {
    final metrics = widget.metrics.value;
    if (metrics == null) {
      return;
    }
    final geometry = _ThumbGeometry.of(metrics, height);
    final y = details.localPosition.dy;
    if (y >= geometry.top && y <= geometry.bottom) {
      _dragStartY = y;
      _dragStartPixels = metrics.pixels;
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double height) {
    final startY = _dragStartY;
    final metrics = widget.metrics.value;
    final position = _position;
    if (startY == null || metrics == null || position == null) {
      return;
    }
    final geometry = _ThumbGeometry.of(metrics, height);
    final travel = geometry.trackLength - geometry.length;
    if (travel <= 0) {
      return;
    }
    final scrollable = metrics.maxScrollExtent - metrics.minScrollExtent;
    final next = _dragStartPixels +
        (details.localPosition.dy - startY) / travel * scrollable;
    position.jumpTo(
      next.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _onTapDown(d, height),
          onVerticalDragStart: (d) => _onDragStart(d, height),
          onVerticalDragUpdate: (d) => _onDragUpdate(d, height),
          onVerticalDragEnd: (_) => _dragStartY = null,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _jumpBy(event.scrollDelta.dy);
              }
            },
            child: CustomPaint(
              size: Size(NexusClassicScrollbar.thickness, height),
              painter: _ScrollbarPainter(widget.metrics),
            ),
          ),
        );
      },
    );
  }
}

class _ThumbGeometry {
  const _ThumbGeometry(this.top, this.length, this.trackLength);

  /// Arrow button length; the thumb travels between the buttons.
  static const button = 17.0;
  static const minLength = 17.0;

  final double top;
  final double length;
  final double trackLength;

  double get bottom => top + length;

  static _ThumbGeometry of(ScrollMetrics metrics, double height) {
    final trackLength = math.max(0.0, height - 2 * (button + 1));
    final scrollable = metrics.maxScrollExtent - metrics.minScrollExtent;
    final content = scrollable + metrics.viewportDimension;
    final length = content <= 0
        ? trackLength
        : math.min(
            trackLength,
            math.max(
              minLength,
              trackLength * metrics.viewportDimension / content,
            ),
          );
    final fraction = scrollable <= 0
        ? 0.0
        : ((metrics.pixels - metrics.minScrollExtent) / scrollable)
            .clamp(0.0, 1.0);
    return _ThumbGeometry(
      button + 1 + (trackLength - length) * fraction,
      length,
      trackLength,
    );
  }
}

class _ScrollbarPainter extends CustomPainter {
  _ScrollbarPainter(this.metrics) : super(repaint: metrics);

  final ValueNotifier<ScrollMetrics?> metrics;

  static const _track = Color(0xFF2C2C2C);
  static const _thumb = Color(0xFF9F9F9F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _track);
    final paint = Paint()
      ..color = _thumb
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = _thumb
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    // Up / down arrows: 9px wide, 7px tall rounded triangles.
    final up = Path()
      ..moveTo(7.5, 5.8)
      ..lineTo(3.8, 11.2)
      ..lineTo(11.2, 11.2)
      ..close();
    canvas
      ..drawPath(up, paint)
      ..drawPath(up, stroke);
    final h = size.height;
    final down = Path()
      ..moveTo(7.5, h - 4.8)
      ..lineTo(3.8, h - 10.2)
      ..lineTo(11.2, h - 10.2)
      ..close();
    canvas
      ..drawPath(down, paint)
      ..drawPath(down, stroke);

    final current = metrics.value;
    if (current == null) {
      return;
    }
    final geometry = _ThumbGeometry.of(current, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, geometry.top, 9, geometry.length),
        const Radius.circular(4.5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScrollbarPainter oldDelegate) =>
      oldDelegate.metrics != metrics;
}
