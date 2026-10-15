import 'package:flutter/material.dart';

import '../../ui/redesign/rd_widgets.dart';

/// Primary line of a state panel (`#d7dfef` on the redesign canvas).
const itemsStateTitleColor = Color(0xFFD7DFEF);

/// Error / empty / not-found block of the items pages.
///
/// Errors are announced as a live region (the canvas uses `role="alert"`).
class ItemsStatePanel extends StatelessWidget {
  const ItemsStatePanel({
    required this.title,
    this.message,
    this.action,
    this.alert = false,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? action;

  /// Announce the panel to screen readers when it appears.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final panel = SizedBox(
      width: double.infinity,
      child: RdCard.tile(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                color: itemsStateTitleColor,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: compact ? 8 : 10),
              Text(
                message!,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  color: RdColors.secondary2,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 12 : 10),
              action!,
            ],
          ],
        ),
      ),
    );
    return alert ? Semantics(liveRegion: true, child: panel) : panel;
  }
}

/// Inner error block of a section (recipe / Penguin Stats failures).
class ItemsInlineError extends StatelessWidget {
  const ItemsInlineError({
    required this.title,
    required this.message,
    this.color = RdColors.inner,
    super.key,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(RdRadii.inner),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: itemsStateTitleColor),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: RdColors.secondary2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Option of an [ItemsSelect].
class ItemsSelectOption<T> {
  const ItemsSelectOption(this.value, this.label);

  final T value;
  final String label;
}

/// Compact dropdown of the canvas (`#121a2c`, 1px line, radius 10/12).
///
/// Used for the Penguin Stats sort and server pickers; [label] names the
/// control for screen readers and as its tooltip.
class ItemsSelect<T> extends StatelessWidget {
  const ItemsSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.width,
    this.height = 36,
    super.key,
  });

  final String label;
  final T value;
  final List<ItemsSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    final radius = height >= 44 ? RdRadii.control : RdRadii.small;
    return Semantics(
      label: label,
      value: selected?.label,
      button: true,
      child: PopupMenuButton<T>(
        tooltip: label,
        initialValue: value,
        onSelected: onChanged,
        color: RdColors.inner,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.small),
          side: const BorderSide(color: RdColors.line3),
        ),
        constraints: BoxConstraints(minWidth: width),
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<T>(
              value: option.value,
              height: 44,
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 13,
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
            children: [
              Expanded(
                child: Text(
                  selected?.label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: RdColors.text),
                ),
              ),
              const Icon(
                Icons.expand_more,
                size: 16,
                color: RdColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
