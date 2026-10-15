import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/rich_text_segment.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view_model.dart';
import 'operators_common.dart';
import 'potential_diff_display.dart';

typedef TermTapCallback = void Function(String key, String label);

/// Description paragraph style of the detail canvas (14px, line-height 1.75).
const detailBodyStyle = TextStyle(
  fontSize: 14,
  height: 1.75,
  color: RdColors.body,
);

/// Port of `components/RichTextContent.vue`.
///
/// Values render as plain text with potential-diff badges appended inline;
/// `<@ba.*>` highlights are `#6ecfff`/600; `<$...>` terms are underlined
/// links (`#7ccfff`, hover `#a6ddff`) that open the term sheet.
class RichTextContent extends StatefulWidget {
  const RichTextContent({
    required this.segments,
    this.style,
    this.onTermTap,
    super.key,
  });

  final List<RichTextSegment> segments;
  final TextStyle? style;
  final TermTapCallback? onTermTap;

  @override
  State<RichTextContent> createState() => _RichTextContentState();
}

class _RichTextContentState extends State<RichTextContent> {
  final List<TapGestureRecognizer> _recognizers = [];
  int? _hoveredTerm;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    var termIndex = 0;

    List<InlineSpan> badgesFor(List<RichInlineBadge> badges) {
      return [
        for (final badge in badges) ...[
          const WidgetSpan(child: SizedBox(width: 5)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _InlineBadge(badge: badge, fontSize: base.fontSize ?? 14),
          ),
        ],
      ];
    }

    List<InlineSpan> spansFor(List<RichTextSegment> segments) {
      final spans = <InlineSpan>[];
      for (final segment in segments) {
        switch (segment) {
          case RichTextRun(:final text):
            spans.add(TextSpan(text: text));
          case RichValueRun(:final text, :final badges):
            spans.add(TextSpan(text: text));
            spans.addAll(badgesFor(badges));
          case RichHighlightRun(:final children):
            spans.add(
              TextSpan(
                style: const TextStyle(
                  color: Color(0xFF6ECFFF),
                  fontWeight: FontWeight.w600,
                ),
                children: spansFor(children),
              ),
            );
          case RichTermRun(:final key, :final text, :final badges):
            final index = termIndex++;
            final recognizer = TapGestureRecognizer()
              ..onTap = () => widget.onTermTap?.call(key, text);
            _recognizers.add(recognizer);
            final hovered = _hoveredTerm == index;
            final color =
                hovered ? const Color(0xFFA6DDFF) : const Color(0xFF7CCFFF);
            spans.add(
              TextSpan(
                text: text,
                recognizer: recognizer,
                mouseCursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredTerm = index),
                onExit: (_) => setState(() {
                  if (_hoveredTerm == index) {
                    _hoveredTerm = null;
                  }
                }),
                style: TextStyle(
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
            );
            spans.addAll(badgesFor(badges));
        }
      }
      return spans;
    }

    return Text.rich(
      TextSpan(children: spansFor(widget.segments)),
      style: base,
    );
  }
}

/// Potential-diff badge (`값(+delta)` with the potential icon).
class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.badge, required this.fontSize});

  final RichInlineBadge badge;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final icon = badge.iconAsset;
    return Container(
      padding: EdgeInsets.fromLTRB(icon != null ? 3 : 8, 1, 8, 1),
      decoration: BoxDecoration(
        color: RdColors.soft,
        borderRadius: BorderRadius.circular(RdRadii.pill),
        border: Border.all(color: RdColors.white8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Image.asset(icon, width: 15, height: 15, fit: BoxFit.contain),
            const SizedBox(width: 4),
          ],
          Text(
            badge.text,
            style: TextStyle(
              fontSize: fontSize * 0.8,
              height: 1.4,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
              color: const Color(0xFFEEF2FB),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas chip (`chipPlain` / `chipCaution`) with inline children.
class DetailChip extends StatelessWidget {
  const DetailChip({required this.children, this.caution = false, super.key});

  DetailChip.text(String label, {bool caution = false, Key? key})
      : this(children: [Text(label)], caution: caution, key: key);

  final List<Widget> children;
  final bool caution;

  @override
  Widget build(BuildContext context) {
    return OpChip(
      kind: caution ? OpChipKind.caution : OpChipKind.plain,
      children: children,
    );
  }
}

/// Condition chip: elite icon + `Lv.N`, or the plain [label] when there is no
/// level (common trait fallback).
class ConditionChip extends StatelessWidget {
  const ConditionChip({
    this.elite,
    this.level,
    this.label = '',
    super.key,
  });

  final int? elite;
  final int? level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DetailChip(
      children: [
        if (elite != null && rdEliteAsset(elite) != null)
          RdEliteIcon(elite!, size: 18),
        Text(level != null ? 'Lv.$level' : label),
      ],
    );
  }
}

/// Attack range grid: `●` marks the operator, blue cells are in range.
class RangeGrid extends StatelessWidget {
  const RangeGrid(this.matrix, {this.cell = 28, super.key});

  final RangeMatrix matrix;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final active =
        matrix.rows.expand((row) => row).where((cell) => cell.isActive).length;
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Semantics(
          image: true,
          label: '$active · ${matrix.id}',
          excludeSemantics: true,
          child: Container(
            key: ValueKey('range-${matrix.id}'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xD6070A12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RdColors.white8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                for (final row in matrix.rows)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      for (final value in row) _RangeCell(value, size: cell),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeCell extends StatelessWidget {
  const _RangeCell(this.cell, {required this.size});

  final RangeMatrixCell cell;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color border, Gradient? gradient, Color? fill) = cell.isOrigin
        ? (
            const Color(0x6BFFD078),
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x57FFD166), Color(0x33FFA554)],
            ),
            null,
          )
        : cell.isActive
            ? (
                const Color(0x5C70C6FF),
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x3D54A8FF), Color(0x296FE9FF)],
                ),
                null,
              )
            : (RdColors.soft, null, RdColors.white3);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: cell.isOrigin
          ? const Text(
              '●',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFF5D6),
              ),
            )
          : null,
    );
  }
}

/// Potential variants that could not be folded into inline badges, shared by
/// talent cards and module candidates (top border, one card per variant).
class PotentialVariantList extends StatelessWidget {
  const PotentialVariantList({
    required this.variants,
    this.ranges = const {},
    this.rangeCell = 28,
    this.onTermTap,
    super.key,
  });

  final List<TalentPotentialVariant> variants;

  /// Range matrix per variant key (module candidates only).
  final Map<String, RangeMatrix?> ranges;
  final double rangeCell;
  final TermTapCallback? onTermTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RdColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          for (final variant in variants)
            if (variant.hasFallback || ranges[variant.key] != null)
              Container(
                key: ValueKey(variant.key),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: RdColors.white3,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    if (variant.hasFallback) ...[
                      DetailChip.text(variant.potentialLabel),
                      RichTextContent(
                        segments: variant.fallbackDescriptionSegments!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xFFDDE4F4),
                        ),
                        onTermTap: onTermTap,
                      ),
                    ],
                    if (ranges[variant.key] case final range?)
                      RangeGrid(range, cell: rangeCell),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Wrap of header pieces (`flex flex-wrap items-center gap-2`).
class DetailHeaderWrap extends StatelessWidget {
  const DetailHeaderWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
