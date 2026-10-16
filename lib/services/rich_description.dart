import '../domain/operator.dart';
import '../domain/rich_text_segment.dart';

/// Dart port of the Vue `parseRichDescription` composable
/// (`src/composables/useRichDescription.ts`). Resolves Arknights markup tags
/// (`<@ba.*>`, `<$...>`) and `{key}` / `{key:0%}` blackboard placeholders into
/// styled [RichTextSegment]s.
List<RichTextSegment> parseRichDescription(
  String text, [
  List<OperatorBlackboardEntry> blackboard = const [],
]) {
  final segments = <RichTextSegment>[];
  var cursor = 0;

  while (true) {
    final start = text.indexOf('<', cursor);
    if (start == -1) {
      _appendPlainText(segments, text.substring(cursor), blackboard);
      return segments;
    }

    _appendPlainText(segments, text.substring(cursor, start), blackboard);
    final rest = text.substring(start);
    if (!(rest.startsWith('<@') || rest.startsWith(r'<$'))) {
      _appendText(segments, '<');
      cursor = start + 1;
      continue;
    }

    final tagCloseOffset = rest.indexOf('>');
    if (tagCloseOffset == -1) {
      _appendText(segments, rest);
      return segments;
    }

    final tagName = rest.substring(1, tagCloseOffset);
    final contentStart = start + tagCloseOffset + 1;
    // A tag the data never closes (`+23%<@ba.talpu>(+3%)`) runs to the end.
    final closingTag = _findClosingTag(text, contentStart);
    final contentEnd = closingTag == -1 ? text.length : closingTag;

    final content = text.substring(contentStart, contentEnd);
    if (_isTermLinkTag(tagName)) {
      segments.add(
        RichTermRun(
          key: tagName.substring(1),
          // `<$ba.root><@ba.vup>속박</></>`: the term shows its text only.
          text: content.contains('<')
              ? _flatten(parseRichDescription(content, blackboard))
              : _resolveMarkupContent(content, blackboard),
        ),
      );
    } else if (_isBlueAccentTag(tagName)) {
      segments.add(RichHighlightRun(parseRichDescription(content, blackboard)));
    } else {
      _appendPlainText(
        segments,
        _resolveMarkupContent(content, blackboard),
        blackboard,
      );
    }

    if (closingTag == -1) {
      return segments;
    }
    cursor = closingTag + 3;
  }
}

/// Index of the `</>` that closes the tag whose content starts at [from],
/// skipping tags nested inside it (`<@ba.rem>... <@ba.vup>+{atk:0%}</>...</>`);
/// -1 when it is never closed.
int _findClosingTag(String text, int from) {
  var depth = 1;
  var cursor = from;
  while (true) {
    final close = text.indexOf('</>', cursor);
    if (close == -1) {
      return -1;
    }
    var open = text.indexOf('<', cursor);
    while (open != -1 && open < close && !_opensTag(text, open)) {
      open = text.indexOf('<', open + 1);
    }
    if (open != -1 && open < close) {
      depth++;
      cursor = open + 2;
      continue;
    }
    depth--;
    if (depth == 0) {
      return close;
    }
    cursor = close + 3;
  }
}

String _flatten(List<RichTextSegment> segments) => segments
    .map(
      (segment) => switch (segment) {
        RichTextRun(:final text) => text,
        RichValueRun(:final text) => text,
        RichTermRun(:final text) => text,
        RichHighlightRun(:final children) => _flatten(children),
      },
    )
    .join();

bool _opensTag(String text, int index) =>
    (text.startsWith('<@', index) || text.startsWith(r'<$', index)) &&
    text.indexOf('>', index) != -1;

bool _isBlueAccentTag(String tagName) => tagName.contains('ba.');

bool _isTermLinkTag(String tagName) => tagName.startsWith(r'$');

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
}

OperatorBlackboardEntry? _lookupEntry(
  List<OperatorBlackboardEntry> blackboard,
  String key,
) {
  for (final item in blackboard) {
    if (item.key.trim() == key) {
      return item;
    }
  }
  return null;
}

String? _lookupText(List<OperatorBlackboardEntry> blackboard, String key) {
  final entry = _lookupEntry(blackboard, key);
  if (entry == null) {
    return null;
  }
  final valueStr = entry.valueStr?.trim();
  if (valueStr != null && valueStr.isNotEmpty) {
    return valueStr;
  }
  return entry.value == null ? null : _formatNumber(entry.value!);
}

String? _lookupPercent(List<OperatorBlackboardEntry> blackboard, String key) {
  final entry = _lookupEntry(blackboard, key);
  if (entry == null || entry.value == null) {
    return null;
  }
  return '${_formatNumber(entry.value! * 100)}%';
}

String _resolveMarkupContent(
  String content,
  List<OperatorBlackboardEntry> blackboard,
) {
  final trimmed = content.trim();
  final separatorIndex = trimmed.indexOf(':');
  final key = separatorIndex >= 0 ? trimmed.substring(0, separatorIndex) : null;
  final format =
      separatorIndex >= 0 ? trimmed.substring(separatorIndex + 1) : null;

  if (format == '0%' && key != null) {
    final percent = _lookupPercent(blackboard, key.trim());
    if (percent != null) {
      return percent;
    }
  }

  final directMatch = _lookupText(blackboard, trimmed);
  if (directMatch != null) {
    return directMatch;
  }

  return _resolvePlainText(content, blackboard);
}

String _resolvePlaceholderToken(
  String token,
  List<OperatorBlackboardEntry> blackboard,
) {
  final trimmed = token.trim();
  final separatorIndex = trimmed.indexOf(':');
  final key =
      separatorIndex >= 0 ? trimmed.substring(0, separatorIndex) : trimmed;
  final format =
      separatorIndex >= 0 ? trimmed.substring(separatorIndex + 1) : null;

  if (format == '0%') {
    final percent = _lookupPercent(blackboard, key.trim());
    if (percent != null) {
      return percent;
    }
  }

  final text = _lookupText(blackboard, key.trim());
  if (text != null) {
    return text;
  }

  return '{$token}';
}

final _placeholderPattern = RegExp(r'\{([^{}]+)\}');

String _resolvePlainText(
  String text,
  List<OperatorBlackboardEntry> blackboard,
) {
  return text.replaceAllMapped(
    _placeholderPattern,
    (match) => _resolvePlaceholderToken(match.group(1) ?? '', blackboard),
  );
}

void _appendText(List<RichTextSegment> segments, String text) {
  if (text.isEmpty) {
    return;
  }
  final previous = segments.isNotEmpty ? segments.last : null;
  if (previous is RichTextRun) {
    segments[segments.length - 1] = RichTextRun(previous.text + text);
  } else {
    segments.add(RichTextRun(text));
  }
}

/// Splits [text] on `{...}` placeholders, emitting plain runs for the gaps and
/// [RichValueRun]s for the resolved blackboard values.
void _appendPlainText(
  List<RichTextSegment> segments,
  String text,
  List<OperatorBlackboardEntry> blackboard,
) {
  var cursor = 0;
  for (final match in _placeholderPattern.allMatches(text)) {
    _appendText(segments, text.substring(cursor, match.start));
    segments.add(
      RichValueRun(
        _resolvePlaceholderToken(match.group(1) ?? '', blackboard),
      ),
    );
    cursor = match.end;
  }
  _appendText(segments, text.substring(cursor));
}
