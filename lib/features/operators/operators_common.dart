import 'package:flutter/material.dart';

import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';

/// Shared visual pieces of the redesigned operators screens.

/// Fill of the operator list tiles and detail panels (a surface-2 card).
const opPanelFill = RdColors.surface2;

/// Colour kinds of the canvas chips (`CHIP_KIND`).
enum OpChipKind { team, nation, group, prof, branch, plain, ba, caution }

/// Small chip (radius 6) of the detail canvas. [children] may mix text and
/// icons.
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
    // Palette A keeps one neutral chip; only the profession (accent), the
    // base-skill tags (accent outline) and cautions (warning) stand out.
    final (Color border, Color fill, Color text) = switch (kind) {
      OpChipKind.team ||
      OpChipKind.nation ||
      OpChipKind.group ||
      OpChipKind.branch ||
      OpChipKind.plain =>
        (RdColors.border, RdColors.surface3, RdColors.text2),
      OpChipKind.prof => (
          RdColors.accentSoft,
          RdColors.accentSoft,
          RdColors.accentText,
        ),
      OpChipKind.ba => (
          RdColors.accentLine,
          RdColors.surface3,
          RdColors.accentText,
        ),
      OpChipKind.caution => (
          RdColors.warningFill,
          RdColors.warningFill,
          RdColors.warningText,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(RdRadii.chip),
        border: Border.all(color: border),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 12, height: 1.2, color: text),
        child: Row(mainAxisSize: MainAxisSize.min, children: spaced),
      ),
    );
  }
}

/// "미실장 · EN": the label of an operator the selected region has not
/// released, shown with the official data of the [source] region.
String unreleasedLabel(NexusI18n i18n, String source) =>
    i18n.t('rd.operators.unreleased', {'source': source.toUpperCase()});

/// Badge of an unreleased operator: [label] from [unreleasedLabel], and
/// [tooltip] the full explanation when there is room for one.
class UnreleasedBadge extends StatelessWidget {
  const UnreleasedBadge({
    required this.label,
    this.tooltip,
    this.small = false,
    super.key,
  });

  final String label;
  final String? tooltip;

  /// The list tile size (over the portrait).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 8,
        vertical: small ? 1 : 3,
      ),
      // Violet: over a portrait the badge needs an opaque fill and outline.
      decoration: BoxDecoration(
        color: small ? RdColors.unreleasedSolid : RdColors.unreleasedFill,
        borderRadius: BorderRadius.circular(RdRadii.chip),
        border: small ? Border.all(color: RdColors.unreleasedLine) : null,
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: TextStyle(
          fontSize: small ? 10 : 12,
          height: small ? 1.3 : 1.2,
          fontWeight: small ? FontWeight.w700 : FontWeight.w600,
          color: RdColors.unreleased,
        ),
      ),
    );
    final message = tooltip;
    return message == null ? badge : Tooltip(message: message, child: badge);
  }
}

/// [UnreleasedBadge]'s tooltip for an operator from [source].
String unreleasedDescription(NexusI18n i18n, String source) => i18n.t(
      'rd.operators.unreleased.description',
      {'source': source.toUpperCase()},
    );

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
