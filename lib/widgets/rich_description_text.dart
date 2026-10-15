import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../domain/operator.dart';
import '../domain/rich_text_segment.dart';
import '../services/rich_description.dart';

/// Renders an Arknights rich-text description, resolving `<@ba.*>` accents,
/// `<$...>` term links and `{key}` blackboard placeholders into styled spans.
///
/// Counterpart to the Vue `RichTextContent` component; without it the raw
/// markup (e.g. `<@ba.vup>{atk:0%}</>`) leaked into the UI as literal text.
/// Term links (`<$...>`) are tappable when [onTermTap] is supplied, mirroring
/// the term-description drawer of the desktop/web build.
class RichDescriptionText extends StatefulWidget {
  const RichDescriptionText(
    this.text, {
    super.key,
    this.blackboard = const [],
    this.style,
    this.onTermTap,
  });

  final String text;
  final List<OperatorBlackboardEntry> blackboard;
  final TextStyle? style;

  /// Called with the term key (e.g. `ba.stun`) and its displayed label when a
  /// term link is tapped.
  final void Function(String key, String label)? onTermTap;

  @override
  State<RichDescriptionText> createState() => _RichDescriptionTextState();
}

class _RichDescriptionTextState extends State<RichDescriptionText> {
  final List<TapGestureRecognizer> _recognizers = [];

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

    final theme = Theme.of(context);
    final baseStyle =
        widget.style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final accentColor = theme.colorScheme.primary;
    final termColor = theme.colorScheme.tertiary;

    final segments = parseRichDescription(widget.text, widget.blackboard);
    return Text.rich(
      TextSpan(
        children: segments
            .map((segment) => _spanFor(segment, accentColor, termColor))
            .toList(),
      ),
      style: baseStyle,
    );
  }

  InlineSpan _spanFor(
    RichTextSegment segment,
    Color accentColor,
    Color termColor,
  ) {
    switch (segment) {
      case RichTextRun(:final text):
        return TextSpan(text: text);
      case RichValueRun(:final text):
        return TextSpan(
          text: text,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
        );
      case RichHighlightRun(:final children):
        return TextSpan(
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
          children: children
              .map((child) => _spanFor(child, accentColor, termColor))
              .toList(),
        );
      case RichTermRun(:final key, :final text):
        final onTermTap = widget.onTermTap;
        TapGestureRecognizer? recognizer;
        if (onTermTap != null) {
          recognizer = TapGestureRecognizer()
            ..onTap = () => onTermTap(key, text);
          _recognizers.add(recognizer);
        }
        return TextSpan(
          text: text,
          recognizer: recognizer,
          style: TextStyle(
            color: termColor,
            fontWeight: FontWeight.w600,
            decoration: onTermTap != null ? TextDecoration.underline : null,
          ),
        );
    }
  }
}
