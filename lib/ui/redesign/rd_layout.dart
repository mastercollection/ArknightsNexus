import 'package:flutter/widgets.dart';

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
