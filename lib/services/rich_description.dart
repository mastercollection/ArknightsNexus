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

/// A `{key}` placeholder of a game description: `{-key}` negates the value
/// and `{key:0%}`, `{key:0.0%}`, `{key:0.0}`, `{key:0}` give its format.
class BlackboardPlaceholder {
  const BlackboardPlaceholder(this.key, {this.negate = false, this.format});

  /// Parses the text between the braces.
  factory BlackboardPlaceholder.parse(String token) {
    var body = token.trim();
    final negate = body.startsWith('-');
    if (negate) {
      body = body.substring(1);
    }
    final separator = body.indexOf(':');
    return BlackboardPlaceholder(
      (separator >= 0 ? body.substring(0, separator) : body).trim(),
      negate: negate,
      format: separator >= 0 ? body.substring(separator + 1).trim() : null,
    );
  }

  final String key;
  final bool negate;
  final String? format;

  bool get isPercent => format?.endsWith('%') ?? false;
}

/// [key] in [blackboard], ignoring case (`atk_scale_AOE` / `atk_scale_aoe`).
OperatorBlackboardEntry? findBlackboardEntry(
  List<OperatorBlackboardEntry> blackboard,
  String key,
) {
  final wanted = key.trim().toLowerCase();
  for (final item in blackboard) {
    if (item.key.trim().toLowerCase() == wanted) {
      return item;
    }
  }
  return null;
}

/// [entry]'s value as [placeholder] shows it in the description: `0.4` with
/// `:0%` is `40%`, `{-def:0%}` with `-0.3` is `30%`. Null when there is no
/// number to format.
String? formatBlackboardValue(
  OperatorBlackboardEntry entry, [
  BlackboardPlaceholder placeholder = const BlackboardPlaceholder(''),
]) {
  final valueStr = entry.valueStr?.trim();
  if (placeholder.format == null &&
      !placeholder.negate &&
      valueStr != null &&
      valueStr.isNotEmpty) {
    return valueStr;
  }
  final raw = entry.value;
  if (raw == null) {
    return valueStr == null || valueStr.isEmpty ? null : valueStr;
  }
  final value = placeholder.negate ? -raw : raw;
  return switch (placeholder.format) {
    '0%' => '${_formatNumber(value * 100)}%',
    '0.0%' => '${(value * 100).toStringAsFixed(1)}%',
    '0.0' => value.toStringAsFixed(1),
    '0' => value.round().toString(),
    _ => _formatNumber(value),
  };
}

/// The value a `{token}` stands for, or null when [blackboard] lacks it.
String? resolveBlackboardToken(
  String token,
  List<OperatorBlackboardEntry> blackboard,
) {
  final placeholder = BlackboardPlaceholder.parse(token);
  final entry = findBlackboardEntry(blackboard, placeholder.key);
  return entry == null ? null : formatBlackboardValue(entry, placeholder);
}

String _resolveMarkupContent(
  String content,
  List<OperatorBlackboardEntry> blackboard,
) {
  return resolveBlackboardToken(content, blackboard) ??
      _resolvePlainText(content, blackboard);
}

String _resolvePlaceholderToken(
  String token,
  List<OperatorBlackboardEntry> blackboard,
) {
  return resolveBlackboardToken(token, blackboard) ?? '{$token}';
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
