import 'package:flutter/material.dart';

import 'rd_feedback.dart';
import 'rd_tokens.dart';

export 'rd_feedback.dart';
export 'rd_inputs.dart';
export 'rd_layout.dart';
export 'rd_media.dart';
export 'rd_sheet.dart';
export 'rd_tokens.dart';

/// Card surface (surface-2, hairline outline, radius 14).
class RdCard extends StatelessWidget {
  const RdCard({
    required this.child,
    EdgeInsetsGeometry this.padding = const EdgeInsets.all(20),
    this.color = RdColors.card,
    double this.radius = RdRadii.card,
    this.borderColor = RdColors.line2,
    super.key,
  });

  /// Card of the list and detail pages: radius 14 and, unless [padding] is
  /// given, 18px padding (14 on phones).
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
        borderRadius: BorderRadius.circular(radius ?? RdRadii.tile),
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
        ? RdColors.accentSoft
        : filled
            ? RdColors.surface3
            : Colors.transparent;
    final side = active
        ? const BorderSide(color: RdColors.accentLine)
        : filled
            ? const BorderSide(color: RdColors.border)
            : BorderSide.none;
    Widget glyph = Icon(
      icon,
      size: iconSize,
      color: !enabled
          ? RdColors.text3
          : iconColor ?? (active ? RdColors.accentText : RdColors.text2),
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
            side: side,
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
          RdColors.surface3,
          RdColors.text,
          RdColors.border,
        ),
      RdButtonVariant.ghost => (
          Colors.transparent,
          RdColors.text2,
          RdColors.border,
        ),
      RdButtonVariant.danger => (
          RdColors.dangerFill,
          RdColors.dangerText,
          RdColors.dangerLine,
        ),
      RdButtonVariant.tonal => enabled || busy
          ? (RdColors.accentSoft, RdColors.accentText, RdColors.accentLine)
          : (RdColors.white3, RdColors.text3, RdColors.border),
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
                        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
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

/// Filter chip (radius 6); [selected] uses the accent fill and outline.
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
        color: selected ? RdColors.accentSoft : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.chip),
          side: BorderSide(
            color: selected ? RdColors.accentLine : RdColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.chip),
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
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? RdColors.accentText : RdColors.text2,
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

/// Small non-interactive badge (status, tag, rarity), radius 6.
class RdPill extends StatelessWidget {
  const RdPill({
    required this.label,
    this.color = RdColors.surface3,
    this.textColor = RdColors.text2,
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
        borderRadius: BorderRadius.circular(RdRadii.chip),
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
  FocusNode? _ownFocusNode;

  /// The caller's node, or one of our own; its focus draws the accent ring.
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focusNode.addListener(_changed);
  }

  @override
  void didUpdateWidget(RdSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_changed);
      _focusNode.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focusNode.removeListener(_changed);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: widget.height,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: RdColors.surface3,
        borderRadius: BorderRadius.circular(RdRadii.control),
        border: Border.all(
          color: _focusNode.hasFocus ? RdColors.accentLine : RdColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: RdColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
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
                  color: RdColors.text3,
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

/// Segmented control (`radiogroup`, surface-3 track, equal-width segments,
/// the selected one accent-soft). [height] is the segment height; the track
/// adds 3px around it.
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
    const gap = 2.0;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: RdColors.segmentTrack,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
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
        color: on ? RdColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                        color: on ? RdColors.accentText : RdColors.text2,
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
/// PC (medium/expanded): a rounded surface-1 card inside the page padding.
/// Compact: a full-width surface-1 bar with a hairline below it and no
/// [subtitle] (phones show the title alone).
///
/// [onBack] adds the 44px back button. Section roots (the pages a rail or
/// tab opens) pass none: Esc, the mouse back button and Android back still
/// climb through the shell. [leading] sits between the back button and the
/// title (app mark, item icon).
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

  /// Clamps the subtitle (with an ellipsis); unlimited when null. Compact
  /// layouts never show the subtitle.
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
        if (!compact && subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: subtitleMaxLines,
            overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            style: RdText.muted,
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
          color: RdColors.surface1,
          border: Border(bottom: BorderSide(color: RdColors.hairline)),
        ),
        child: SafeArea(bottom: false, child: content),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: RdColors.surface1,
        borderRadius: BorderRadius.circular(RdRadii.card),
        border: Border.all(color: RdColors.hairline),
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
