import 'package:flutter/material.dart';

import '../../ui/redesign/rd_widgets.dart';

/// Shared visual pieces of the redesigned operators screens.

/// `rgba(10,15,30,0.78)` panel fill of the operators canvas.
const opPanelFill = Color(0xC70A0F1E);

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
          RdColors.blueFill,
          RdColors.blueText,
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
          RdColors.white10,
          RdColors.line2,
          RdColors.body,
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
        RdStepButton(
          increase: false,
          tooltip: decreaseTooltip,
          width: buttonSize,
          height: buttonSize,
          onPressed: clamped > min ? () => onChanged(clamped - 1) : null,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: RdColors.accent,
              inactiveTrackColor: RdColors.white20,
              thumbColor: RdColors.accent,
              overlayColor: RdColors.chipOnFill,
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
        RdStepButton(
          increase: true,
          tooltip: increaseTooltip,
          width: buttonSize,
          height: buttonSize,
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
