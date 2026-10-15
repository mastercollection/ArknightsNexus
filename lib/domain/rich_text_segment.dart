/// Parsed pieces of an Arknights rich-text description.
///
/// Upstream skill / talent / trait descriptions embed markup tags such as
/// `<@ba.vup>...</>` (blue accent), `<$ba.stun>...</>` (term link) and
/// blackboard placeholders like `{atk_scale:0%}`. Mirrors the Vue
/// `RichTextSegment` union in `src/types/operator-view.ts`.
sealed class RichTextSegment {
  const RichTextSegment();
}

/// Small pill rendered after a value/term, e.g. a potential diff
/// (`RichInlineBadge` in `src/types/operator-view.ts`).
class RichInlineBadge {
  const RichInlineBadge({required this.text, this.iconAsset});

  final String text;

  /// Bundled asset path of the leading icon (potential rank icon).
  final String? iconAsset;

  @override
  String toString() => 'Badge($text, $iconAsset)';
}

/// Plain text with no special styling.
class RichTextRun extends RichTextSegment {
  const RichTextRun(this.text);

  final String text;

  @override
  String toString() => 'Text($text)';
}

/// An interpolated blackboard value (rendered emphasized).
class RichValueRun extends RichTextSegment {
  const RichValueRun(this.text, {this.badges = const []});

  final String text;
  final List<RichInlineBadge> badges;

  @override
  String toString() => 'Value($text, $badges)';
}

/// A blue-accent highlighted span (`<@ba.*>`), may contain nested segments.
class RichHighlightRun extends RichTextSegment {
  const RichHighlightRun(this.children);

  final List<RichTextSegment> children;

  @override
  String toString() => 'Highlight($children)';
}

/// A term-link span (`<$...>`), pointing at a game term by [key].
class RichTermRun extends RichTextSegment {
  const RichTermRun({
    required this.key,
    required this.text,
    this.badges = const [],
  });

  final String key;
  final String text;
  final List<RichInlineBadge> badges;

  @override
  String toString() => 'Term($key, $text, $badges)';
}
