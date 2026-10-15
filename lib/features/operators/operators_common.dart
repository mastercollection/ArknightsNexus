import 'package:flutter/material.dart';

import '../../data_sources/image_source.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../../widgets/cached_image.dart';

/// Shared visual pieces of the redesigned operators screens.

/// `rgba(10,15,30,0.78)` panel fill of the operators canvas.
const opPanelFill = Color(0xC70A0F1E);

/// `rgba(255,255,255,0.07)` panel border.
const opPanelBorder = Color(0x12FFFFFF);

/// Body copy of descriptions (`#e6ecf8`).
const opBodyColor = Color(0xFFE6ECF8);

/// Cached operator portrait in a rounded `#16223a` box; the initial letter
/// stands in while the image is missing.
class OpPortrait extends StatelessWidget {
  const OpPortrait({
    required this.charId,
    required this.name,
    required this.size,
    required this.radius,
    super.key,
  });

  final String charId;
  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? ''
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: RdColors.cyan,
        ),
      ),
    );
    final id = charId.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RdColors.portrait,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: id.isEmpty
          ? fallback
          : CachedImage(
              kind: CachedImageKind.portrait,
              id: id,
              size: size,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.zero,
              placeholder: fallback,
            ),
    );
  }
}

/// Colour kinds of the canvas chips (`CHIP_KIND`).
enum OpChipKind { team, nation, group, prof, branch, plain, ba, caution }

/// Small pill chip of the detail canvas. [children] may mix text and icons.
class OpChip extends StatelessWidget {
  const OpChip({
    required this.children,
    this.kind = OpChipKind.plain,
    super.key,
  });

  OpChip.text(String label, {OpChipKind kind = OpChipKind.plain, Key? key})
      : this(children: [Text(label)], kind: kind, key: key);

  final List<Widget> children;
  final OpChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, Color text) = switch (kind) {
      OpChipKind.team => (
          const Color(0x4771A5FF),
          const Color(0x2971A5FF),
          const Color(0xFFDCE9FF),
        ),
      OpChipKind.nation => (
          const Color(0x47C4B5FD),
          const Color(0x29C4B5FD),
          const Color(0xFFE9DDFF),
        ),
      OpChipKind.group => (
          const Color(0x47F472B6),
          const Color(0x29F472B6),
          const Color(0xFFFFD3E7),
        ),
      OpChipKind.prof => (
          const Color(0x47FFC54F),
          const Color(0x29FFC54F),
          const Color(0xFFFFE3A3),
        ),
      OpChipKind.branch => (
          const Color(0x4734D399),
          const Color(0x2934D399),
          const Color(0xFFBBF7D0),
        ),
      OpChipKind.plain => (
          const Color(0x1AFFFFFF),
          const Color(0x12FFFFFF),
          opBodyColor,
        ),
      OpChipKind.ba => (
          const Color(0x855EB6FF),
          const Color(0x241C3560),
          const Color(0xFFE0EFFF),
        ),
      OpChipKind.caution => (
          const Color(0x38FF9A66),
          const Color(0x1FFF8A5C),
          const Color(0xFFFFE4D6),
        ),
    };
    final spaced = <Widget>[];
    for (final child in children) {
      if (spaced.isNotEmpty) {
        spaced.add(const SizedBox(width: 6));
      }
      spaced.add(child);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(RdRadii.pill),
        border: Border.all(
          color: border,
          width: kind == OpChipKind.ba ? 2 : 1,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 12, height: 1.2, color: text),
        child: Row(mainAxisSize: MainAxisSize.min, children: spaced),
      ),
    );
  }
}

/// One option of [OpSegmented].
class OpSegment<T> {
  const OpSegment(this.value, this.label, {this.leading});

  final T value;
  final String label;

  /// Icon shown before the label (elite icon).
  final Widget? leading;
}

/// Segmented control of the detail canvas (`radiogroup`, track `#111a2c`,
/// equal-width segments, selected `rgba(92,148,220,0.9)`).
class OpSegmented<T> extends StatelessWidget {
  const OpSegmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 40,
    this.semanticLabel,
    super.key,
  });

  final List<OpSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: RdColors.segmentTrack,
          borderRadius: BorderRadius.circular(RdRadii.control),
        ),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _segment(segments[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(OpSegment<T> segment) {
    final on = segment.value == value;
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: on ? RdColors.segmentOn : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(segment.value),
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
                        fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                        color:
                            on ? const Color(0xFFF3F8FF) : RdColors.secondary2,
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

/// Square outlined stepper button (`−` / `+` next to the range sliders).
class OpStepButton extends StatelessWidget {
  const OpStepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RdRadii.small),
            side: const BorderSide(color: Color(0x24FFFFFF)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(RdRadii.small),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: 18,
                color: onPressed == null ? RdColors.muted : RdColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `− slider +` row with a monospace readout (level and skill level).
class OpRangeControl extends StatelessWidget {
  const OpRangeControl({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.readout,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    this.semanticLabel,
    this.buttonSize = 40,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Widget readout;
  final String decreaseTooltip;
  final String increaseTooltip;
  final String? semanticLabel;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max < min ? min : max);
    final enabled = max > min;
    return Row(
      children: [
        OpStepButton(
          icon: Icons.remove,
          tooltip: decreaseTooltip,
          size: buttonSize,
          onPressed: clamped > min ? () => onChanged(clamped - 1) : null,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: RdColors.accent,
              inactiveTrackColor: const Color(0x33FFFFFF),
              thumbColor: RdColors.accent,
              overlayColor: const Color(0x2985B6FF),
              trackHeight: 4,
              showValueIndicator: ShowValueIndicator.never,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: clamped.toDouble(),
              min: min.toDouble(),
              max: (enabled ? max : min + 1).toDouble(),
              divisions: enabled ? max - min : null,
              semanticFormatterCallback: (value) =>
                  '${semanticLabel ?? ''} ${value.round()}'.trim(),
              onChanged: enabled ? (value) => onChanged(value.round()) : null,
            ),
          ),
        ),
        OpStepButton(
          icon: Icons.add,
          tooltip: increaseTooltip,
          size: buttonSize,
          onPressed: clamped < max ? () => onChanged(clamped + 1) : null,
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: readout,
          ),
        ),
      ],
    );
  }
}

/// `h3 + p` heading pair of the detail panels.
class OpHeading extends StatelessWidget {
  const OpHeading(
    this.title, {
    this.description,
    this.fontSize = 15,
    super.key,
  });

  final String title;
  final String? description;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFECF0FA),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: RdText.muted),
        ],
      ],
    );
  }
}

/// Grid whose column count follows CSS `repeat(auto-fill, minmax(min, 1fr))`.
class OpAutoGrid extends StatelessWidget {
  const OpAutoGrid({
    required this.minTileWidth,
    required this.children,
    this.gap = 10,
    super.key,
  });

  final double minTileWidth;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            ((width + gap) / (minTileWidth + gap)).floor().clamp(1, 99);
        // Floored so rounding never pushes the last tile to a new run.
        final tileWidth =
            ((width - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
