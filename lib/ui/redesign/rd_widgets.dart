import 'package:flutter/material.dart';

import 'rd_feedback.dart';
import 'rd_tokens.dart';

export 'rd_feedback.dart';
export 'rd_layout.dart';
export 'rd_media.dart';
export 'rd_tokens.dart';

/// Card surface (`#0c1426`, 1px line, radius 20).
class RdCard extends StatelessWidget {
  const RdCard({
    required this.child,
    EdgeInsetsGeometry this.padding = const EdgeInsets.all(22),
    this.color = RdColors.card,
    double this.radius = RdRadii.card,
    this.borderColor = RdColors.line2,
    super.key,
  });

  /// Card of the list and detail pages: radius 18 (16 on phones) and, unless
  /// [padding] is given, 18px padding (14 on phones).
  const RdCard.tile({
    required this.child,
    this.padding,
    this.color = RdColors.card,
    this.borderColor = RdColors.line2,
    super.key,
  }) : radius = null;

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double? radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    return Container(
      padding: padding ?? EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius:
            BorderRadius.circular(radius ?? (compact ? 16 : RdRadii.tile)),
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
    this.iconColor,
    this.iconSize = 20,
    this.toggled,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final bool active;

  /// Overrides the icon colour while enabled (gold favorite star).
  final Color? iconColor;
  final double iconSize;

  /// Announces a toggle button in this state (favorite on/off).
  final bool? toggled;

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
      size: iconSize,
      color: !enabled
          ? RdColors.muted
          : iconColor ?? (active ? RdColors.text : RdColors.secondary),
    );
    if (spinning) {
      glyph = RdSpin(child: glyph);
    }
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: toggled,
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

enum RdButtonVariant { primary, secondary, ghost, danger, tonal }

/// Text button of the redesign. [primary] is the accent-filled call to
/// action, [secondary] the inner-card button, [ghost] an outlined one and
/// [tonal] the accent-tinted button of the phone layouts and settings cards
/// (greyed out instead of faded while disabled).
class RdButton extends StatelessWidget {
  const RdButton({
    required this.label,
    required this.onPressed,
    this.variant = RdButtonVariant.secondary,
    this.icon,
    this.height = 44,
    this.expand = false,
    this.busy = false,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final RdButtonVariant variant;
  final IconData? icon;

  /// Minimum height; a label on several lines ([maxLines]) grows the button.
  final double height;
  final bool expand;
  final int maxLines;

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
      RdButtonVariant.tonal => enabled || busy
          ? (RdColors.tonalFill, RdColors.text, RdColors.tonalBorder)
          : (RdColors.white3, RdColors.placeholder, RdColors.white8),
    };
    final bold =
        variant == RdButtonVariant.primary || variant == RdButtonVariant.tonal;
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
      opacity: enabled || busy || variant == RdButtonVariant.tonal ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
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
              constraints: BoxConstraints(minHeight: height),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
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

/// One option of an [RdSegmented].
class RdSegment<T> {
  const RdSegment(this.value, this.label, {this.leading, this.key});

  final T value;
  final String label;

  /// Icon before the label (elite icon).
  final Widget? leading;

  /// Key of the segment's semantics node (tests and automation).
  final Key? key;
}

/// Segmented control (`radiogroup`, track `#111a2c`, equal-width segments,
/// selected `rgba(92,148,220,0.9)`). [height] is the segment height; the
/// track adds 4px (3px on phones) around it.
class RdSegmented<T> extends StatelessWidget {
  const RdSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 40,
    this.semanticLabel,
    super.key,
  });

  final List<RdSegment<T>> segments;

  /// No segment is highlighted while this is null.
  final T? selected;
  final ValueChanged<T>? onChanged;
  final double height;

  /// Names the group for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gap = context.rdLayout == RdLayout.compact ? 3.0 : 4.0;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(
          color: RdColors.segmentTrack,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: _segment(segments[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(RdSegment<T> segment) {
    final on = segment.value == selected;
    final onChanged = this.onChanged;
    return Semantics(
      key: segment.key,
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: on ? RdColors.segmentOn : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap:
              on || onChanged == null ? null : () => onChanged(segment.value),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (segment.leading != null) ...[
                  segment.leading!,
                  if (segment.label.isNotEmpty) const SizedBox(width: 6),
                ],
                if (segment.label.isNotEmpty)
                  Flexible(
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? RdColors.onSegment : RdColors.secondary2,
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

/// Header bar of a redesigned page.
///
/// PC (medium/expanded): a rounded `#070c19` card inside the page padding.
/// Compact: a full-width bar with a bottom border. [onBack] adds the 44px
/// back button; [leading] sits between it and the title (app mark, item
/// icon).
class RdPageHeader extends StatelessWidget {
  const RdPageHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.onBack,
    this.backTooltip = '',
    this.backKey,
    this.leading,
    this.actions = const [],
    this.trailingTitle,
    this.bottom,
    this.compactTitleStyle = RdText.mobileTitle,
    this.subtitleMaxLines,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onBack;
  final String backTooltip;
  final Key? backKey;
  final Widget? leading;
  final List<Widget> actions;

  /// Title style on phones (PC uses [RdText.pageTitle]).
  final TextStyle compactTitleStyle;

  /// Clamps the subtitle (with an ellipsis); unlimited when null.
  final int? subtitleMaxLines;

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
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: compact ? compactTitleStyle : RdText.pageTitle,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: compact ? 2 : 4),
          Text(
            subtitle!,
            maxLines: subtitleMaxLines,
            overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            style: compact ? RdText.small : RdText.secondary,
          ),
        ],
      ],
    );
    final row = Row(
      children: [
        if (onBack != null) ...[
          RdIconButton(
            key: backKey,
            icon: Icons.chevron_left,
            tooltip: backTooltip,
            filled: !compact,
            onPressed: onBack,
          ),
          SizedBox(width: compact ? 8 : 14),
        ],
        if (leading != null) ...[
          leading!,
          SizedBox(width: compact ? 10 : 14),
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
