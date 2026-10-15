import 'package:flutter/material.dart';

import 'rd_tokens.dart';

/// Option of an [RdSelect].
class RdSelectOption<T> {
  const RdSelectOption(this.value, this.label, {this.shortLabel});

  final T value;

  /// Label in the menu (and in the closed field unless [shortLabel] is set).
  final String label;

  /// Label of the closed field ("KR" for "KR · 한국어").
  final String? shortLabel;
}

/// Dropdown of the canvas (`#121a2c`, 1px line, radius 10/12).
///
/// [label] names the control for screen readers and as its tooltip. Without
/// [width] the field fills its parent, or wraps its label when [shrinkWrap]
/// is set.
class RdSelect<T> extends StatelessWidget {
  const RdSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width,
    this.height = 36,
    this.fontSize = 13,
    this.shrinkWrap = false,
    super.key,
  });

  final String label;
  final T value;
  final List<RdSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final double? width;
  final double height;
  final double fontSize;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    final radius = height >= 44 ? RdRadii.control : RdRadii.small;
    final shown = Text(
      selected?.shortLabel ?? selected?.label ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, color: RdColors.text),
    );
    return Semantics(
      label: label,
      value: selected?.label,
      button: true,
      child: PopupMenuButton<T>(
        tooltip: label,
        initialValue: value,
        onSelected: (next) {
          if (next != value) {
            onChanged(next);
          }
        },
        color: RdColors.inner,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.small),
          side: const BorderSide(color: RdColors.line3),
        ),
        constraints: BoxConstraints(minWidth: width ?? 0),
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<T>(
              value: option.value,
              height: 44,
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      option.value == value ? FontWeight.w700 : FontWeight.w400,
                  color: option.value == value
                      ? RdColors.accent
                      : RdColors.secondary,
                ),
              ),
            ),
        ],
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: RdColors.field,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: RdColors.line3),
          ),
          child: Row(
            mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (shrinkWrap) shown else Expanded(child: shown),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more,
                size: height >= 40 ? 18 : 16,
                color: RdColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
