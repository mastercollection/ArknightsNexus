import 'package:flutter/material.dart';

import 'nexus_icons.dart';
import 'nexus_tokens.dart';

/// Surface variants matching the UnoCSS shortcuts of the Tauri app.
enum NexusSurfaceVariant {
  /// `panel`: gradient glass panel, 24px radius.
  panel,

  /// `panel-soft`: translucent navy fill, 24px radius.
  panelSoft,

  /// `card-tile`: gradient tile, 22px radius.
  cardTile,

  /// `stat-card`: translucent navy fill, 20px radius.
  statCard,
}

class NexusSurface extends StatelessWidget {
  const NexusSurface({
    required this.child,
    this.variant = NexusSurfaceVariant.panel,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.color,
    this.gradient,
    this.radius,
    this.clip = false,
    this.asButton = false,
    super.key,
  });

  const NexusSurface.panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? borderColor,
    Key? key,
  }) : this(
          child: child,
          padding: padding,
          borderColor: borderColor,
          key: key,
        );

  const NexusSurface.soft({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Key? key,
  }) : this(
          child: child,
          padding: padding,
          variant: NexusSurfaceVariant.panelSoft,
          key: key,
        );

  final Widget child;
  final NexusSurfaceVariant variant;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final Gradient? gradient;
  final double? radius;
  final bool clip;

  /// The Vue element is a `<button>`. The Tauri app ships no CSS reset, so
  /// UnoCSS `border` only shows on buttons (UA border-style) and other
  /// elements stay borderless; translucent button fills also show Chromium's
  /// dark `ButtonFace` underneath. Explicit [borderColor] always draws.
  final bool asButton;

  double get _radius =>
      radius ??
      switch (variant) {
        NexusSurfaceVariant.panel => NexusRadii.panel,
        NexusSurfaceVariant.panelSoft => NexusRadii.panel,
        NexusSurfaceVariant.cardTile => NexusRadii.tile,
        NexusSurfaceVariant.statCard => NexusRadii.card,
      };

  @override
  Widget build(BuildContext context) {
    final gradientFill = gradient ??
        (color == null &&
                (variant == NexusSurfaceVariant.panel ||
                    variant == NexusSurfaceVariant.cardTile)
            ? NexusColors.panelGradient
            : null);
    final border = borderColor ??
        (!asButton
            ? null
            : variant == NexusSurfaceVariant.panelSoft
                ? const Color(0x12FFFFFF)
                : NexusColors.line);

    final borderRadius = BorderRadius.circular(_radius);
    final decoration = BoxDecoration(
      color: gradientFill == null ? (color ?? NexusColors.softFill) : null,
      gradient: gradientFill,
      borderRadius: borderRadius,
      border: border == null ? null : Border.all(color: border),
    );
    // `panel` / `card-tile` carry `shadow-glass` (inset top highlight).
    final glass = variant == NexusSurfaceVariant.panel ||
        variant == NexusSurfaceVariant.cardTile;
    final surface = Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: decoration,
      child: glass
          ? CustomPaint(
              painter: InsetTopHighlightPainter(
                radius: _radius,
                inset: border == null ? 0 : 1,
              ),
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
    if (!asButton) {
      return surface;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NexusColors.buttonFace,
        borderRadius: borderRadius,
      ),
      child: surface,
    );
  }
}

/// CSS `box-shadow: inset 0 1px 0 <color>` (e.g. UnoCSS `shadow-glass`): a
/// 1px highlight along the inside of the rounded top edge. Use as the
/// `painter` of a [CustomPaint] between the background and the content.
class InsetTopHighlightPainter extends CustomPainter {
  const InsetTopHighlightPainter({
    required this.radius,
    this.color = const Color(0x08FFFFFF),
    this.inset = 0,
    this.bottom = false,
  });

  /// `shadow-glass`: `inset 0 1px 0 rgba(255,255,255,0.03)`.
  static const glass = Color(0x08FFFFFF);

  final double radius;
  final Color color;

  /// Border width to stay inside of (inset shadows sit inside the border).
  final double inset;

  /// Draw along the bottom edge instead (a 1px `border-bottom`).
  final bool bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(inset),
      Radius.circular((radius - inset).clamp(0, double.infinity)),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(outer.shift(Offset(0, bottom ? -1 : 1))),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(InsetTopHighlightPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.inset != inset ||
      oldDelegate.bottom != bottom;
}

/// `chip` / `chip-caution`.
class NexusChip extends StatelessWidget {
  const NexusChip({
    required this.label,
    this.caution = false,
    this.background,
    this.foreground,
    this.borderColor,
    this.fontSize = 13.12,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    super.key,
  });

  final String label;
  final bool caution;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double fontSize;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (caution ? const Color(0x1FFF8A5C) : const Color(0x12FFFFFF));
    final fg = foreground ??
        (caution ? const Color(0xF0FFE4D6) : NexusColors.chipText);
    // chip-caution's border is on a <span>, which has no border-style
    // without a CSS reset, so only an explicit borderColor draws one.
    final border = borderColor;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NexusRadii.pill),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, height: 1, color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds the web app's hover/press affordances to any surface: pointer cursor,
/// hover state for colour transitions, and an optional 2px lift.
class NexusHoverable extends StatefulWidget {
  const NexusHoverable({
    required this.builder,
    this.onTap,
    this.lift = false,
    super.key,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final bool lift;

  @override
  State<NexusHoverable> createState() => _NexusHoverableState();
}

class _NexusHoverableState extends State<NexusHoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: widget.lift && enabled && _hovered
              ? const Offset(0, -0.01)
              : Offset.zero,
          child: widget.builder(context, enabled && _hovered),
        ),
      ),
    );
  }
}

/// `action-btn`.
class NexusActionButton extends StatelessWidget {
  const NexusActionButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // `button { font: inherit }`: the label takes the surrounding font size
    // with a `normal` line box.
    final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 16;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: NexusHoverable(
        onTap: onPressed,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: hovered ? const Color(0x2E5984FF) : const Color(0x1A5984FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x52679EFF)),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                NexusIcon(icon!, size: 16, color: const Color(0xFFDBE8FF)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFDBE8FF),
                    fontSize: fontSize,
                    height: NexusText.normalHeight(fontSize),
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `top-bar-icon`: 40x40 square icon button.
class NexusTopBarIcon extends StatelessWidget {
  const NexusTopBarIcon({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.spinning = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget =
        NexusIcon(icon, size: 16, color: const Color(0xE0EBF0FF));
    if (spinning) {
      iconWidget = _Spinner(child: iconWidget);
    }
    final button = NexusHoverable(
      onTap: onPressed,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovered ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NexusColors.line),
        ),
        child: iconWidget,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.child});

  final Widget child;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
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

/// `ghost-link`: borderless text button that brightens on hover.
class NexusGhostLink extends StatelessWidget {
  const NexusGhostLink({
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return NexusHoverable(
      onTap: onTap,
      builder: (context, hovered) {
        final color = hovered ? Colors.white : const Color(0xDBEBF0FF);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              NexusIcon(icon!, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: color)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              NexusIcon(trailingIcon!, size: 16, color: color),
            ],
          ],
        );
      },
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.lineHeight, super.key});

  final String text;

  /// Line box in px; defaults to Chromium's `normal` for 12.48px text.
  /// Pass the inherited CSS line-height where the parent sets one.
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    final size = NexusText.eyebrow.fontSize!;
    return Text(
      text.toUpperCase(),
      style: NexusText.eyebrow.copyWith(
        height: lineHeight == null
            ? NexusText.normalHeightFor(text, size)
            : lineHeight! / size,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.fontSize, super.key});

  final String text;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: fontSize == null
          ? NexusText.sectionTitle
          : NexusText.sectionTitle.copyWith(fontSize: fontSize),
    );
  }
}

class MutedText extends StatelessWidget {
  const MutedText(
    this.text, {
    this.fontSize,
    this.height,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final String text;
  final double? fontSize;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: NexusText.muted.copyWith(fontSize: fontSize, height: height),
    );
  }
}

/// Spaced column, the Flutter counterpart of `grid gap-N`.
class Gap extends StatelessWidget {
  const Gap({
    required this.children,
    this.gap = 16,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (final child in children) {
      if (spaced.isNotEmpty) {
        spaced.add(SizedBox(height: gap));
      }
      spaced.add(child);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: spaced,
    );
  }
}

/// Responsive equal-width grid (`grid grid-cols-N gap-X`) that sizes rows to
/// their tallest child.
class NexusGrid extends StatelessWidget {
  const NexusGrid({
    required this.children,
    required this.columns,
    this.gap = 14,
    this.rowGap,
    super.key,
  });

  final List<Widget> children;

  /// Column count for a given available width.
  final int Function(double width) columns;
  final double gap;
  final double? rowGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = columns(constraints.maxWidth).clamp(1, 12);
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += count) {
          final cells = <Widget>[];
          for (var i = 0; i < count; i++) {
            if (i > 0) {
              cells.add(SizedBox(width: gap));
            }
            final index = start + i;
            cells.add(
              Expanded(
                child: index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: rowGap ?? gap));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
