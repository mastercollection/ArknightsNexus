import 'package:intl/intl.dart';

import '../../domain/item.dart';

/// Upper bound of the owned-count editor (`items.vue`).
const maxOwnedCount = 9999999;

final _ownedCountFormatter = NumberFormat.decimalPattern();

/// Port of `formatOwnedCount` from `items.vue`; LMD keeps a compact K/M
/// notation from 1,000 up. Smaller LMD counts are written out so an empty
/// wallet reads "0" rather than "0.0K".
String formatOwnedCount(num count, [String? itemId]) {
  final normalized = count < 0 ? 0 : count.truncate();
  if (itemId != lmdItemId || normalized < 1000) {
    return _ownedCountFormatter.format(normalized);
  }
  if (normalized < 1000000) {
    return '${(normalized / 1000).toStringAsFixed(1)}K';
  }
  return '${(normalized / 1000000).toStringAsFixed(1)}M';
}

/// Port of `normalizeOwnedCountInput`: digits only, empty -> `0`, clamped.
String normalizeOwnedCountInput(String value) {
  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) {
    return '0';
  }
  final parsed = BigInt.parse(digitsOnly);
  final clamped =
      parsed > BigInt.from(maxOwnedCount) ? maxOwnedCount : parsed.toInt();
  return '$clamped';
}

/// Clamp used by `setOwnedCountDraftValue`.
int clampOwnedCount(num value) {
  final truncated = value.truncate();
  if (truncated < 0) {
    return 0;
  }
  return truncated > maxOwnedCount ? maxOwnedCount : truncated;
}

/// Hold-to-repeat step from `getHoldStep`.
int ownedCountHoldStep(Duration elapsed) {
  if (elapsed.inMilliseconds >= 3000) {
    return 10;
  }
  if (elapsed.inMilliseconds >= 1500) {
    return 5;
  }
  return 1;
}

/// JavaScript `String(number)` for counts that are usually integral.
String formatJsNumber(num value) {
  if (value == value.truncate()) {
    return '${value.truncate()}';
  }
  return '$value';
}

/// Penguin stage ids may carry a `_perm` suffix that the stage-code map omits.
String penguinStageLabel(String stageId, Map<String, String> stageCodeMap) {
  final normalized =
      stageId.replaceAll(RegExp(r'_perm$', caseSensitive: false), '');
  final direct = stageCodeMap[stageId];
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final fallback = stageCodeMap[normalized];
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return stageId;
}

/// Lazy incremental rendering state from `useInfiniteSlice.ts`.
class InfiniteSlice {
  InfiniteSlice({required this.initialCount, required this.batchSize})
      : visibleCount = initialCount;

  final int initialCount;
  final int batchSize;
  int visibleCount;

  /// `reset()`: back to the first page for a new source list.
  void reset(int sourceLength) {
    visibleCount = initialCount < sourceLength ? initialCount : sourceLength;
  }

  /// `loadMore()`: returns whether anything was added.
  bool loadMore(int sourceLength) {
    if (visibleCount >= sourceLength) {
      return false;
    }
    final next = visibleCount + batchSize;
    visibleCount = next < sourceLength ? next : sourceLength;
    return true;
  }

  int visibleLength(int sourceLength) {
    return visibleCount < sourceLength ? visibleCount : sourceLength;
  }

  bool hasMore(int sourceLength) => visibleCount < sourceLength;
}

/// Kind of an item, derived from the game data: the item table has no
/// single field for it (`classifyType` is `MATERIAL` for chips, skill
/// summaries and class tokens alike), so the id families and `itemType`
/// decide.
enum ItemKind {
  /// LMD (`itemType` GOLD).
  currency,

  /// Battle records (`itemType` CARD_EXP).
  exp,

  /// Skill summaries (`3301`…`3303`).
  skill,

  /// Module data block / data supplement (`mod_*`).
  module,

  /// Chips, dualchips and the chip catalyst (`32xx`, `32001`).
  chip,

  /// Elite / promotion materials (everything else that is a material).
  material,

  /// Class tokens (`tier<N>_<class>`).
  token,

  /// Any non-material item a detail page can still be opened for.
  other,
}

final _skillIdPattern = RegExp(r'^33\d\d$');
final _chipIdPattern = RegExp(r'^32\d+$');
final _tokenIdPattern = RegExp(r'^tier\d_');
final _tierPattern = RegExp(r'(\d+)');

/// [ItemKind] of [item]; see the enum for the rules.
ItemKind itemKindOf(ItemEntry item) {
  final id = item.itemId;
  final itemType = item.itemType.toUpperCase();
  if (itemType == 'GOLD') {
    return ItemKind.currency;
  }
  if (itemType == 'CARD_EXP') {
    return ItemKind.exp;
  }
  if (item.classifyType.toUpperCase() != 'MATERIAL') {
    return ItemKind.other;
  }
  if (_skillIdPattern.hasMatch(id)) {
    return ItemKind.skill;
  }
  if (id.startsWith('mod_')) {
    return ItemKind.module;
  }
  if (_chipIdPattern.hasMatch(id)) {
    return ItemKind.chip;
  }
  if (_tokenIdPattern.hasMatch(id)) {
    return ItemKind.token;
  }
  return ItemKind.material;
}

/// Tier (1…6) from the rarity (`TIER_4` in the game data); 0 when unknown.
int itemTierOf(ItemEntry item) {
  final match = _tierPattern.firstMatch(item.rarity);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Kinds whose list section is split into tier sub-sections (T6 first).
bool itemKindHasTierSections(ItemKind kind) =>
    kind == ItemKind.material || kind == ItemKind.token;

/// Whether the detail header shows a tier chip: LMD's rarity says nothing.
bool itemKindShowsTier(ItemKind kind) =>
    kind != ItemKind.currency && kind != ItemKind.other;
