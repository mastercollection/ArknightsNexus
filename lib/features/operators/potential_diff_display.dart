import '../../domain/operator.dart';
import '../../domain/rich_text_segment.dart';
import '../../services/rich_description.dart';

/// Port of `src/composables/usePotentialDiffDisplay.ts`.
///
/// Folds potential-rank variants of a talent/trait into the base description:
/// numbers that change between ranks get an inline badge (`값(+delta)` with
/// the potential icon); variants whose structure differs fall back to a full
/// separate description.
final displayValueTokenPattern = RegExp(
  r'[+\-]?\d+(?:\.\d+)?%?(?:~[+\-]?\d+(?:\.\d+)?%?)?(?:\([+\-]?\d+(?:\.\d+)?%?(?:~[+\-]?\d+(?:\.\d+)?%?)?\))?',
);

class TalentPotentialVariant {
  const TalentPotentialVariant({
    required this.key,
    required this.requiredPotentialRank,
    required this.potentialLabel,
    this.fallbackDescriptionSegments,
  });

  final String key;
  final int requiredPotentialRank;
  final String potentialLabel;
  final List<RichTextSegment>? fallbackDescriptionSegments;

  bool get hasFallback => fallbackDescriptionSegments?.isNotEmpty ?? false;
}

class PotentialDiffDisplay {
  const PotentialDiffDisplay({
    required this.baseDescriptionSegments,
    this.basePotentialLabel,
    this.potentialVariants = const [],
  });

  final List<RichTextSegment> baseDescriptionSegments;
  final String? basePotentialLabel;
  final List<TalentPotentialVariant> potentialVariants;
}

/// Stable sort (JS `Array.prototype.sort` is stable; Dart's is not).
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.toList().asMap().entries.toList()
    ..sort((a, b) {
      final result = compare(a.value, b.value);
      return result != 0 ? result : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}

PotentialDiffDisplay buildPotentialDiffDisplay({
  required List<OperatorTrait> candidates,
  required String keyPrefix,
  required String Function(int requiredPotentialRank) getPotentialLabel,
  required String? Function(int requiredPotentialRank) getPotentialIcon,
}) {
  final sorted = stableSorted(
    candidates,
    (a, b) => a.requiredPotentialRank - b.requiredPotentialRank,
  );
  if (sorted.isEmpty) {
    return const PotentialDiffDisplay(baseDescriptionSegments: []);
  }

  final base = sorted.firstWhere(
    (candidate) => candidate.requiredPotentialRank == 0,
    orElse: () => sorted.first,
  );
  final baseSegments = parseRichDescription(base.description, base.blackboard);
  final inlineBadgeMap = <int, List<RichInlineBadge>>{};
  final seenSignatures = <String>{segmentsSignature(baseSegments)};
  final variants = <TalentPotentialVariant>[];

  for (final candidate in sorted) {
    if (identical(candidate, base) || candidate.requiredPotentialRank <= 0) {
      continue;
    }
    final descriptionSegments =
        parseRichDescription(candidate.description, candidate.blackboard);
    final signature = segmentsSignature(descriptionSegments);
    if (seenSignatures.contains(signature)) {
      continue;
    }
    seenSignatures.add(signature);

    final potentialLabel = getPotentialLabel(candidate.requiredPotentialRank);
    final talpuBadges = _extractTalpuBadgeTexts(candidate.description);
    final comparisonSegments = talpuBadges.isNotEmpty
        ? parseRichDescription(
            _stripTalpuMarkup(candidate.description),
            candidate.blackboard,
          )
        : descriptionSegments;
    final inlineBadges = _buildVariantDisplayDiffBadges(
      baseSegments,
      comparisonSegments,
      getPotentialIcon(candidate.requiredPotentialRank),
      talpuBadges,
    );

    if (inlineBadges != null) {
      inlineBadges.forEach((index, badges) {
        inlineBadgeMap[index] = [...?inlineBadgeMap[index], ...badges];
      });
    }

    variants.add(
      TalentPotentialVariant(
        key: '$keyPrefix:${candidate.requiredPotentialRank}',
        requiredPotentialRank: candidate.requiredPotentialRank,
        potentialLabel: potentialLabel,
        fallbackDescriptionSegments:
            inlineBadges == null ? descriptionSegments : null,
      ),
    );
  }

  return PotentialDiffDisplay(
    baseDescriptionSegments:
        _applyInlineBadgesToSegments(baseSegments, inlineBadgeMap),
    basePotentialLabel: base.requiredPotentialRank > 0
        ? getPotentialLabel(base.requiredPotentialRank)
        : null,
    potentialVariants: variants,
  );
}

/// Stand-in for `JSON.stringify(segments)`.
String segmentsSignature(List<RichTextSegment> segments) =>
    segments.map((segment) => segment.toString()).join('|');

Map<int, List<RichInlineBadge>>? _buildVariantDisplayDiffBadges(
  List<RichTextSegment> baseSegments,
  List<RichTextSegment> variantSegments,
  String? potentialIcon,
  List<String> talpuBadges,
) {
  final baseTokens = _collectDisplayValueTokens(baseSegments);
  final variantTokens = _collectDisplayValueTokens(variantSegments);
  if (baseTokens.length != variantTokens.length) {
    return null;
  }

  final badgesByIndex = <int, List<RichInlineBadge>>{};
  var changedIndex = 0;
  for (var index = 0; index < baseTokens.length; index++) {
    final baseToken = baseTokens[index];
    final variantToken = variantTokens[index];
    if (baseToken == variantToken) {
      continue;
    }

    final talpuBadge =
        changedIndex < talpuBadges.length ? talpuBadges[changedIndex] : null;
    final hasTalpu = talpuBadge != null && talpuBadge.isNotEmpty;
    final delta = hasTalpu
        ? talpuBadge
        : _summarizeDisplayTokenDelta(baseToken, variantToken);
    final badgeText = hasTalpu
        ? '$variantToken$talpuBadge'
        : (delta != null && delta.isNotEmpty)
            ? '$variantToken($delta)'
            : variantToken;

    badgesByIndex[index] = [
      ...?badgesByIndex[index],
      RichInlineBadge(text: badgeText, iconAsset: potentialIcon),
    ];
    changedIndex += 1;
  }

  return badgesByIndex.isEmpty ? null : badgesByIndex;
}

final _startsWithParenNumber = RegExp(r'^\([+\-]?\d');
final _endsWithNumber = RegExp(r'[+\-]?\d(?:\.\d+)?%?$');
final _endsWithParen = RegExp(r'\)$');

List<String> _collectDisplayValueTokens(List<RichTextSegment> segments) {
  final values = <String>[];
  var pendingToken = '';

  for (final text in _flattenDisplayTexts(segments)) {
    for (final match in displayValueTokenPattern.allMatches(text)) {
      final token = match.group(0)!;
      if (pendingToken.isNotEmpty && _startsWithParenNumber.hasMatch(token)) {
        pendingToken += token;
        values.add(pendingToken);
        pendingToken = '';
        continue;
      }
      if (_endsWithNumber.hasMatch(token) && !_endsWithParen.hasMatch(token)) {
        if (pendingToken.isNotEmpty) {
          values.add(pendingToken);
        }
        pendingToken = token;
        continue;
      }
      if (pendingToken.isNotEmpty) {
        values.add(pendingToken);
        pendingToken = '';
      }
      values.add(token);
    }
  }

  if (pendingToken.isNotEmpty) {
    values.add(pendingToken);
  }
  return values;
}

List<String> _flattenDisplayTexts(List<RichTextSegment> segments) {
  final texts = <String>[];
  for (final segment in segments) {
    switch (segment) {
      case RichHighlightRun(:final children):
        texts.addAll(_flattenDisplayTexts(children));
      case RichTextRun(:final text):
        texts.add(text);
      case RichValueRun(:final text):
        texts.add(text);
      case RichTermRun(:final text):
        texts.add(text);
    }
  }
  return texts;
}

final _inlineDeltaPattern = RegExp(
  r'\(([+\-]?\d+(?:\.\d+)?%?(?:~[+\-]?\d+(?:\.\d+)?%?)?)\)$',
);
final _numberPattern = RegExp(r'-?\d+(?:\.\d+)?');

String? _summarizeDisplayTokenDelta(String baseToken, String variantToken) {
  final inlineDelta = _inlineDeltaPattern.firstMatch(variantToken)?.group(1);
  if (inlineDelta != null && inlineDelta.isNotEmpty) {
    return inlineDelta;
  }

  final baseNumbers =
      _numberPattern.allMatches(baseToken).map((m) => m.group(0)!).toList();
  final variantNumbers =
      _numberPattern.allMatches(variantToken).map((m) => m.group(0)!).toList();
  if (baseNumbers.isEmpty ||
      variantNumbers.isEmpty ||
      baseNumbers.length != variantNumbers.length) {
    return null;
  }

  final baseSkeleton = baseToken.replaceAll(_numberPattern, '#');
  final variantSkeleton = variantToken.replaceAll(_numberPattern, '#');
  if (baseSkeleton != variantSkeleton) {
    return null;
  }

  final deltas = <String>[];
  for (var i = 0; i < baseNumbers.length; i++) {
    final delta =
        double.parse(variantNumbers[i]) - double.parse(baseNumbers[i]);
    if (!delta.isFinite) {
      return null;
    }
    final formatted = _formatSignedNumber(delta);
    if (formatted.isEmpty) {
      return null;
    }
    deltas.add(formatted);
  }

  var diffIndex = 0;
  return baseSkeleton.replaceAllMapped(
    '#',
    (_) => diffIndex < deltas.length ? deltas[diffIndex++] : '',
  );
}

List<RichTextSegment> _applyInlineBadgesToSegments(
  List<RichTextSegment> segments,
  Map<int, List<RichInlineBadge>> badgesByTokenIndex,
) {
  final state = _TokenState();
  return [
    for (final segment in segments)
      ..._applyInlineBadgesToSegment(segment, badgesByTokenIndex, state),
  ];
}

class _TokenState {
  int index = 0;
}

List<RichTextSegment> _applyInlineBadgesToSegment(
  RichTextSegment segment,
  Map<int, List<RichInlineBadge>> badgesByTokenIndex,
  _TokenState state,
) {
  switch (segment) {
    case RichHighlightRun(:final children):
      return [
        RichHighlightRun([
          for (final child in children)
            ..._applyInlineBadgesToSegment(child, badgesByTokenIndex, state),
        ]),
      ];
    case RichTermRun(:final key, :final text, :final badges):
      final tokenCount = displayValueTokenPattern.allMatches(text).length;
      if (tokenCount == 1) {
        final found = badgesByTokenIndex[state.index];
        state.index += 1;
        return found != null && found.isNotEmpty
            ? [RichTermRun(key: key, text: text, badges: found)]
            : [segment];
      }
      state.index += tokenCount;
      return [RichTermRun(key: key, text: text, badges: badges)];
    case RichTextRun(:final text):
      return _splitSegmentTextWithBadges(text, badgesByTokenIndex, state);
    case RichValueRun(:final text):
      return _splitSegmentTextWithBadges(text, badgesByTokenIndex, state);
  }
}

List<RichTextSegment> _splitSegmentTextWithBadges(
  String text,
  Map<int, List<RichInlineBadge>> badgesByTokenIndex,
  _TokenState state,
) {
  final parts = <RichTextSegment>[];
  var cursor = 0;
  for (final match in displayValueTokenPattern.allMatches(text)) {
    if (match.start > cursor) {
      parts.add(RichTextRun(text.substring(cursor, match.start)));
    }
    parts.add(
      RichValueRun(
        match.group(0)!,
        badges: badgesByTokenIndex[state.index] ?? const [],
      ),
    );
    state.index += 1;
    cursor = match.end;
  }
  if (cursor < text.length) {
    parts.add(RichTextRun(text.substring(cursor)));
  }
  return parts;
}

final _talpuPattern = RegExp(r'<@ba\.talpu>(.*?)</>');

List<String> _extractTalpuBadgeTexts(String text) {
  return _talpuPattern
      .allMatches(text)
      .map((match) => (match.group(1) ?? '').trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

String _stripTalpuMarkup(String text) => text.replaceAll(_talpuPattern, '');

String _formatDisplayNumber(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
}

String _formatSignedNumber(double value) {
  final display = _formatDisplayNumber(value);
  return value > 0 ? '+$display' : display;
}
