import 'package:flutter/widgets.dart';

import 'rd_tokens.dart';

/// Column count of CSS `repeat(auto-fill, minmax(minTileWidth, 1fr))` with
/// [gap] between tracks, clamped to [min]..[max].
int rdAutoColumns(
  double width,
  double minTileWidth, {
  double gap = 0,
  int min = 1,
  int max = 99,
}) {
  final columns = ((width + gap) / (minTileWidth + gap)).floor();
  return columns.clamp(min, max < min ? min : max);
}

/// Equal-width grid: [columns] fixed, or as many [minTileWidth]-wide tracks
/// as fit (`repeat(auto-fill, minmax(...))`), at most [maxColumns].
///
/// [equalHeight] stretches the tiles of a row to the tallest one (CSS grid
/// rows); otherwise tiles keep their own height and align to the top.
class RdAutoGrid extends StatelessWidget {
  const RdAutoGrid({
    required this.children,
    this.minTileWidth,
    this.columns,
    this.maxColumns = 99,
    this.gap = 12,
    this.equalHeight = false,
    super.key,
  }) : assert(columns != null || minTileWidth != null);

  final List<Widget> children;
  final double? minTileWidth;
  final int? columns;
  final int maxColumns;
  final double gap;
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = columns ??
            rdAutoColumns(width, minTileWidth!, gap: gap, max: maxColumns);
        if (equalHeight) {
          return _rows(count);
        }
        // Floor so rounding never pushes the last tile onto a new row.
        final tile = ((width - gap * (count - 1)) / count).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: tile, child: child),
          ],
        );
      },
    );
  }

  Widget _rows(int count) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += count) {
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: gap));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: start + i < children.length
                      ? children[start + i]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Tinted block inside a card (`rgba(255,255,255,0.03)`, radius 14).
class RdInset extends StatelessWidget {
  const RdInset({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = RdRadii.inner,
    this.color = RdColors.white3,
    super.key,
  });

  /// Section block of the operator detail panels (`rgba(255,255,255,0.04)`,
  /// radius 20, padding 16).
  const RdInset.section({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = RdColors.soft2,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Section heading: bold [title] (announced as a header) with an optional
/// [description] line below it.
class RdHeading extends StatelessWidget {
  const RdHeading(
    this.title, {
    this.description,
    this.fontSize = 15,
    this.color = RdColors.text,
    this.letterSpacing,
    this.descriptionStyle = RdText.muted,
    super.key,
  });

  final String title;
  final String? description;
  final double fontSize;
  final Color color;
  final double? letterSpacing;
  final TextStyle descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: letterSpacing,
          color: color,
        ),
      ),
    );
    if (description == null || description!.isEmpty) {
      return heading;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        const SizedBox(height: 4),
        Text(description!, style: descriptionStyle),
      ],
    );
  }
}
