import 'package:flutter/material.dart';

import 'rd_widgets.dart';

/// Rotates [child] continuously (sync in progress).
class RdSpin extends StatefulWidget {
  const RdSpin({required this.child, super.key});

  final Widget child;

  @override
  State<RdSpin> createState() => _RdSpinState();
}

class _RdSpinState extends State<RdSpin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// UnoCSS `animate-pulse` applied to a whole subtree (opacity 1 -> .5).
class RdPulse extends StatefulWidget {
  const RdPulse({required this.child, super.key});

  final Widget child;

  @override
  State<RdPulse> createState() => _RdPulseState();
}

class _RdPulseState extends State<RdPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 1, end: 0.5).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.4, 0, 0.6, 1),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Static skeleton block; the pulsing comes from an enclosing [RdPulse].
class RdSkeleton extends StatelessWidget {
  const RdSkeleton({
    this.width,
    this.height = 14,
    this.widthFactor,
    this.radius = RdRadii.pill,
    this.color = RdColors.white8,
    super.key,
  });

  final double? width;
  final double height;

  /// Percentage width (`w-[70%]`), left-aligned.
  final double? widthFactor;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (widthFactor == null) {
      return box;
    }
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}

enum RdStateKind { loading, error, empty }

/// How an [RdStatePanel] is laid out.
enum RdStateLayout {
  /// Centered card standing in for a whole page's content.
  centered,

  /// Left-aligned block on an [RdStateSurface] (section or page states).
  left,

  /// Plain lines inside another card, with an optional [RdStatePanel.leading]
  /// glyph.
  inline,
}

/// Background of a [RdStateLayout.left] panel.
enum RdStateSurface {
  /// [RdCard.tile].
  card,

  /// [RdInset] (radius 16) inside a card.
  inset,

  /// Solid inner block (`#111b30` unless [RdStatePanel.color] is given).
  inner,
}

/// Loading / error / empty block. Errors are announced as a live region (the
/// canvas uses `role="alert"`).
class RdStatePanel extends StatelessWidget {
  const RdStatePanel({
    required this.kind,
    required this.title,
    this.message,
    this.detail,
    this.action,
    this.leading,
    this.layout = RdStateLayout.centered,
    this.surface = RdStateSurface.card,
    this.color,
    super.key,
  });

  final RdStateKind kind;
  final String title;
  final String? message;

  /// Raw error text, shown selectable in monospace below [title].
  final String? detail;
  final Widget? action;

  /// Glyph before the lines of an [RdStateLayout.inline] panel.
  final Widget? leading;
  final RdStateLayout layout;
  final RdStateSurface surface;

  /// Fill of an [RdStateSurface.inner] panel.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final panel = switch (layout) {
      RdStateLayout.centered => _centered(),
      RdStateLayout.left => _left(context),
      RdStateLayout.inline => _inline(),
    };
    return kind == RdStateKind.error
        ? Semantics(liveRegion: true, child: panel)
        : panel;
  }

  Widget _centered() {
    return Container(
      constraints: const BoxConstraints(minHeight: 192),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RdColors.card,
        borderRadius: BorderRadius.circular(RdRadii.card),
        border: Border.all(
          color: kind == RdStateKind.error
              ? RdColors.dangerBorder
              : RdColors.line2,
        ),
      ),
      child: Center(
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
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: RdColors.muted,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }

  Widget _left(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final inner = surface == RdStateSurface.inner;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: inner ? 14 : 15,
            color: RdColors.stateTitle,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          SizedBox(height: inner ? 6 : 8),
          Text(
            message!,
            style: const TextStyle(fontSize: 13, color: RdColors.secondary2),
          ),
        ],
        if (detail != null) ...[
          const SizedBox(height: 10),
          SelectableText(
            detail!,
            style: RdText.mono(fontSize: 13, color: RdColors.secondary2),
          ),
        ],
        if (action != null) ...[
          SizedBox(height: compact ? 12 : 10),
          action!,
        ],
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: switch (surface) {
        RdStateSurface.card => RdCard.tile(child: content),
        RdStateSurface.inset => RdInset(
            padding: EdgeInsets.all(compact ? 16 : 18),
            radius: 16,
            child: content,
          ),
        RdStateSurface.inner => RdInset(
            padding: const EdgeInsets.all(16),
            color: color ?? RdColors.inner,
            child: content,
          ),
      },
    );
  }

  Widget _inline() {
    final error = kind == RdStateKind.error;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: error ? RdColors.dangerText : RdColors.secondary,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: RdColors.muted,
            ),
          ),
        ],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(padding: const EdgeInsets.only(top: 3), child: leading),
          const SizedBox(width: 10),
        ],
        Expanded(child: content),
      ],
    );
  }
}

enum RdNoticeTone { info, warn, danger }

/// Notice block: farming / shortage hints (with an icon) and error banners.
/// Danger notices are announced as a live region.
class RdNotice extends StatelessWidget {
  const RdNotice({
    required this.text,
    this.tone = RdNoticeTone.info,
    this.showIcon = true,
    super.key,
  });

  final String text;
  final RdNoticeTone tone;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color? border, Color color, IconData icon) =
        switch (tone) {
      RdNoticeTone.info => (
          RdColors.soft2,
          null,
          RdColors.secondary,
          Icons.info_outline,
        ),
      RdNoticeTone.warn => (
          RdColors.warnBg,
          null,
          RdColors.warnText,
          Icons.warning_amber_rounded,
        ),
      RdNoticeTone.danger => (
          RdColors.dangerFill,
          RdColors.dangerBorder,
          RdColors.dangerText,
          Icons.error_outline,
        ),
    };
    final notice = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(RdRadii.inner),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.45, color: color),
            ),
          ),
        ],
      ),
    );
    return tone == RdNoticeTone.danger
        ? Semantics(liveRegion: true, child: notice)
        : notice;
  }
}
