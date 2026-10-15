import 'package:flutter/material.dart';

import 'rd_tokens.dart';

export 'rd_tokens.dart';

/// Card surface (`#0c1426`, 1px line, radius 20).
class RdCard extends StatelessWidget {
  const RdCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = RdColors.card,
    this.radius = RdRadii.card,
    this.borderColor = RdColors.line2,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
  }
}

/// Square icon button (back, refresh, filter). 44px by default so it is a
/// valid touch target on phones.
class RdIconButton extends StatelessWidget {
  const RdIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.filled = true,
    this.active = false,
    this.spinning = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final bool active;

  /// Rotates the icon (sync in progress).
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = active
        ? RdColors.chipOnFill
        : filled
            ? RdColors.inner
            : Colors.transparent;
    Widget glyph = Icon(
      icon,
      size: 20,
      color: !enabled
          ? RdColors.muted
          : active
              ? RdColors.text
              : RdColors.secondary,
    );
    if (spinning) {
      glyph = _Spin(child: glyph);
    }
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.control),
            side: active
                ? const BorderSide(color: RdColors.chipOnBorder)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(RdRadii.control),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.child});

  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
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

enum RdButtonVariant { primary, secondary, ghost, danger }

/// Text button of the redesign. [primary] is the accent-filled call to
/// action, [secondary] the inner-card button, [ghost] an outlined one.
class RdButton extends StatelessWidget {
  const RdButton({
    required this.label,
    required this.onPressed,
    this.variant = RdButtonVariant.secondary,
    this.icon,
    this.height = 44,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final RdButtonVariant variant;
  final IconData? icon;
  final double height;
  final bool expand;

  /// Shows a small spinner in place of [icon] and disables the button.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final (Color background, Color foreground, Color? border) =
        switch (variant) {
      RdButtonVariant.primary => (
          RdColors.accent,
          RdColors.onAccent,
          null,
        ),
      RdButtonVariant.secondary => (
          RdColors.inner,
          RdColors.secondary,
          RdColors.line3,
        ),
      RdButtonVariant.ghost => (
          Colors.transparent,
          RdColors.secondary,
          RdColors.line3,
        ),
      RdButtonVariant.danger => (
          const Color(0x1FFF8A8A),
          const Color(0xFFFFC2C2),
          const Color(0x4DFF8A8A),
        ),
    };
    final leading = busy
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        : icon == null
            ? null
            : Icon(icon, size: 16, color: foreground);
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.control),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.control),
          onTap: enabled ? onPressed : null,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: variant == RdButtonVariant.primary
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: foreground,
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

/// Pill chip; [selected] uses the accent outline/fill of the canvas.
class RdChip extends StatelessWidget {
  const RdChip({
    required this.label,
    this.onPressed,
    this.selected = false,
    this.leading,
    this.trailing,
    this.height = 36,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPressed != null,
      selected: selected,
      child: Material(
        color: selected ? RdColors.chipOnFill : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? RdColors.chipOnBorder : RdColors.line3,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? RdColors.text : RdColors.secondary,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small non-interactive label pill (status, tag, rarity).
class RdPill extends StatelessWidget {
  const RdPill({
    required this.label,
    this.color = RdColors.soft,
    this.textColor = RdColors.secondary,
    this.fontSize = 12,
    super.key,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RdRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, color: textColor),
      ),
    );
  }
}

/// Search box with leading magnifier, clear button and optional trailing
/// widget (e.g. an "Enter" hint).
class RdSearchField extends StatefulWidget {
  const RdSearchField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.trailing,
    this.height = 44,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;
  final Widget? trailing;
  final double height;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<RdSearchField> createState() => _RdSearchFieldState();
}

class _RdSearchFieldState extends State<RdSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(RdSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: widget.height,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: RdColors.inner2,
        borderRadius: BorderRadius.circular(RdRadii.control),
        border: Border.all(color: RdColors.searchBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: RdColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 15, color: RdColors.text),
              cursorColor: RdColors.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: RdColors.placeholder,
                ),
              ),
            ),
          ),
          if (hasText)
            RdIconButton(
              icon: Icons.close,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              size: 34,
              filled: false,
              onPressed: () {
                widget.controller.clear();
                widget.onChanged?.call('');
                widget.onCleared?.call();
              },
            ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            widget.trailing!,
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Segmented control (track `#111a2c`, selected `rgba(92,148,220,0.9)`).
class RdSegmented<T> extends StatelessWidget {
  const RdSegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.height = 40,
    this.expand = false,
    super.key,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final String Function(T) labelOf;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget segment(T option) {
      final on = option == selected;
      final child = Semantics(
        selected: on,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged!(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: height - 6,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? RdColors.segmentOn : Colors.transparent,
              borderRadius: BorderRadius.circular(RdRadii.small - 2),
            ),
            child: Text(
              labelOf(option),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? RdColors.onSegment : RdColors.secondary,
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RdColors.segmentTrack,
        borderRadius: BorderRadius.circular(RdRadii.small),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final option in options) segment(option)],
      ),
    );
  }
}

/// Header bar of a redesigned page.
///
/// PC (medium/expanded): a rounded `#070c19` card inside the page padding.
/// Compact: a full-width bar with a bottom border. [onBack] adds the 44px
/// back button.
class RdPageHeader extends StatelessWidget {
  const RdPageHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.onBack,
    this.backTooltip = '',
    this.actions = const [],
    this.trailingTitle,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;

  /// Small widget right after the title (e.g. a count on phones).
  final Widget? trailingTitle;

  /// Extra rows below the title (search, chips).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: RdText.eyebrow),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: compact ? RdText.mobileTitle : RdText.pageTitle,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: compact ? RdText.small : RdText.secondary,
          ),
        ],
      ],
    );
    final row = Row(
      children: [
        if (onBack != null) ...[
          RdIconButton(
            icon: Icons.chevron_left,
            tooltip: backTooltip,
            filled: !compact,
            onPressed: onBack,
          ),
          SizedBox(width: compact ? 6 : 14),
        ],
        Expanded(child: titleBlock),
        if (trailingTitle != null) ...[
          const SizedBox(width: 8),
          trailingTitle!,
        ],
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ],
    );
    final content = bottom == null
        ? row
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [row, const SizedBox(height: 10), bottom!],
          );
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: RdColors.header,
          border: Border(bottom: BorderSide(color: RdColors.line)),
        ),
        child: SafeArea(bottom: false, child: content),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: RdColors.header,
        borderRadius: BorderRadius.circular(RdRadii.card),
        border: Border.all(color: RdColors.line),
      ),
      child: content,
    );
  }
}

enum RdStateKind { loading, error, empty }

/// Loading / error / empty block used in place of a page's content.
class RdStatePanel extends StatelessWidget {
  const RdStatePanel({
    required this.kind,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final RdStateKind kind;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
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
    return kind == RdStateKind.error
        ? Semantics(liveRegion: true, child: panel)
        : panel;
  }
}

/// Page padding of the canvas: `28px clamp(16px, 3vw, 48px) 48px` on PC,
/// 14/16 on phones.
EdgeInsets rdPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (RdBreakpoints.of(width) == RdLayout.compact) {
    return const EdgeInsets.fromLTRB(16, 14, 16, 24);
  }
  final side = (width * 0.03).clamp(16.0, 48.0);
  return EdgeInsets.fromLTRB(side, 28, side, 48);
}
