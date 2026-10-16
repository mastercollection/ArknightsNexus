import 'package:flutter/foundation.dart';

import '../../domain/operator.dart';
import '../../domain/rich_text_segment.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/rich_description.dart';
import 'potential_diff_display.dart';

/// Dart port of `src/composables/useOperatorDetailViewModel.ts`,
/// `useSkillComparisonRows.ts`, `getOperatorStats` (`src/services/operators.ts`)
/// and the module/range helpers from `src/pages/operators/[operatorId].vue`.

// ---------------------------------------------------------------------------
// Static icon assets
// ---------------------------------------------------------------------------

/// `potentialIcons[rank] ?? potentialIcons[1]`.
String potentialIconAsset(int rank) {
  final safe = rank >= 1 && rank <= 6 ? rank : 1;
  return 'assets/icons/potential/$safe.png';
}

int? elitePhaseFromCode(String? phase) {
  return switch (phase) {
    'PHASE_0' => 0,
    'PHASE_1' => 1,
    'PHASE_2' => 2,
    _ => null,
  };
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// JS `Math.round` (rounds .5 toward +infinity).
int _jsRound(double value) => (value + 0.5).floorToDouble().toInt();

double _toFixed1(double value) => double.parse(value.toStringAsFixed(1));

/// Port of `getOperatorStats`.
OperatorStatPoint? operatorStatsAt(
  OperatorDetail detail,
  int elite,
  int level,
) {
  if (detail.stats.isEmpty) {
    return null;
  }
  final safeElite = elite.clamp(0, detail.stats.length - 1);
  final progression = detail.stats[safeElite];
  final maxLevel = safeElite < detail.eliteCaps.length
      ? detail.eliteCaps[safeElite]
      : (detail.eliteCaps.isNotEmpty ? detail.eliteCaps.first : 1);
  final safeLevel = level.clamp(1, maxLevel < 1 ? 1 : maxLevel);
  final progress = maxLevel == 1 ? 1.0 : (safeLevel - 1) / (maxLevel - 1);

  int lerp(int start, int end) => _jsRound(start + (end - start) * progress);
  final min = progression.min;
  final max = progression.max;
  return OperatorStatPoint(
    hp: lerp(min.hp, max.hp),
    attack: lerp(min.attack, max.attack),
    defense: lerp(min.defense, max.defense),
    resistance: lerp(min.resistance, max.resistance),
    redeployTime: lerp(min.redeployTime, max.redeployTime),
    dpCost: lerp(min.dpCost, max.dpCost),
    block: lerp(min.block, max.block),
    attackInterval: _toFixed1(
      min.attackInterval + (max.attackInterval - min.attackInterval) * progress,
    ),
    hpRecoveryPerSec: _toFixed1(
      min.hpRecoveryPerSec +
          (max.hpRecoveryPerSec - min.hpRecoveryPerSec) * progress,
    ),
  );
}

class StatCardItem {
  const StatCardItem(this.key, this.value);

  final String key;
  final String value;
}

List<StatCardItem> buildStatCards(
  OperatorDetail operator,
  int elite,
  int level,
  NexusI18n i18n,
) {
  final stats = operatorStatsAt(operator, elite, level);
  if (stats == null) {
    return const [];
  }
  return [
    StatCardItem('hp', '${stats.hp}'),
    StatCardItem('atk', '${stats.attack}'),
    StatCardItem('def', '${stats.defense}'),
    StatCardItem('magic_res', '${stats.resistance}'),
    StatCardItem('cost', '${stats.dpCost}'),
    StatCardItem('block_cnt', '${stats.block}'),
    StatCardItem('respawn_time', i18n.secondsValue(stats.redeployTime)),
    StatCardItem(
      'attack_interval',
      i18n.secondsValue(stats.attackInterval.toStringAsFixed(1)),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Traits / talents / potentials
// ---------------------------------------------------------------------------

class TraitItem {
  const TraitItem({
    required this.key,
    required this.descriptionSegments,
    required this.conditionLabel,
    this.conditionElite,
    this.conditionLevel,
    this.potentialLabel,
  });

  final String key;
  final List<RichTextSegment> descriptionSegments;
  final String conditionLabel;
  final int? conditionElite;
  final int? conditionLevel;
  final String? potentialLabel;
}

class TalentCard {
  const TalentCard({
    required this.key,
    required this.name,
    required this.baseDescriptionSegments,
    required this.conditionLabel,
    this.conditionElite,
    this.conditionLevel,
    this.basePotentialLabel,
    this.potentialVariants = const [],
  });

  final String key;
  final String name;
  final List<RichTextSegment> baseDescriptionSegments;
  final String conditionLabel;
  final int? conditionElite;
  final int? conditionLevel;
  final String? basePotentialLabel;
  final List<TalentPotentialVariant> potentialVariants;
}

class PotentialItem {
  const PotentialItem({
    required this.key,
    required this.rankLabel,
    required this.iconAsset,
    required this.description,
  });

  final String key;
  final String rankLabel;
  final String iconAsset;
  final String description;
}

int _comparePriority(OperatorTrait left, OperatorTrait right) {
  final elite = left.elite - right.elite;
  if (elite != 0) {
    return elite;
  }
  final level = left.level - right.level;
  if (level != 0) {
    return level;
  }
  return left.requiredPotentialRank - right.requiredPotentialRank;
}

String _conditionLabel(NexusI18n i18n, int elite, int level) {
  return '${i18n.t('operatorDetail.labels.eliteShort', {'elite': elite})} '
      '${i18n.t('operatorDetail.labels.conditionLevel', {'level': level})}';
}

/// Traits of [operator] at [selectedElite]. Without any, the archetype
/// description stands in as the common trait unless [archetypeFallback] is
/// false (a summon shows its description in its own header).
List<TraitItem> buildTraits(
  OperatorDetail operator,
  int selectedElite,
  NexusI18n i18n, {
  bool archetypeFallback = true,
}) {
  final groups = <String, OperatorTrait>{};
  for (final trait in operator.traits.where((t) => t.elite <= selectedElite)) {
    final existing = groups[trait.groupKey];
    if (existing == null || _comparePriority(trait, existing) > 0) {
      groups[trait.groupKey] = trait;
    }
  }
  final selected = stableSorted(
    groups.values,
    (a, b) => a.groupKey.compareTo(b.groupKey),
  );

  if (archetypeFallback &&
      selected.isEmpty &&
      operator.archetypeDescription.trim().isNotEmpty) {
    return [
      TraitItem(
        key: 'archetype-fallback',
        descriptionSegments:
            parseRichDescription(operator.archetypeDescription),
        conditionLabel: i18n.t('operatorDetail.labels.commonTrait'),
      ),
    ];
  }

  return [
    for (final trait in selected)
      TraitItem(
        key:
            '${trait.groupKey}-${trait.elite}-${trait.level}-${trait.requiredPotentialRank}',
        descriptionSegments:
            parseRichDescription(trait.description, trait.blackboard),
        conditionLabel: _conditionLabel(i18n, trait.elite, trait.level),
        conditionElite: trait.elite,
        conditionLevel: trait.level,
        potentialLabel: trait.requiredPotentialRank > 0
            ? i18n.t('operatorDetail.labels.potentialValue', {
                'value': trait.requiredPotentialRank + 1,
              })
            : null,
      ),
  ];
}

List<TalentCard> buildTalents(
  OperatorDetail operator,
  int selectedElite,
  NexusI18n i18n,
) {
  final deduped = <String, OperatorTalent>{};
  for (final talent
      in operator.talents.where((t) => t.elite == selectedElite)) {
    deduped['${talent.groupKey}:${talent.elite}:${talent.level}:${talent.requiredPotentialRank}'] =
        talent;
  }
  final active = stableSorted(deduped.values, (a, b) {
    final group = a.groupKey.compareTo(b.groupKey);
    return group != 0 ? group : _comparePriority(a, b);
  });

  final groups = <String, List<OperatorTalent>>{};
  for (final talent in active) {
    groups
        .putIfAbsent(
          '${talent.groupKey}:${talent.elite}:${talent.level}',
          () => [],
        )
        .add(talent);
  }
  final entries = stableSorted(
    groups.entries,
    (a, b) => a.key.compareTo(b.key),
  );
  return [
    for (final entry in entries) _buildTalentCard(entry.key, entry.value, i18n),
  ];
}

TalentCard _buildTalentCard(
  String key,
  List<OperatorTalent> talents,
  NexusI18n i18n,
) {
  final sorted = stableSorted(talents, (a, b) {
    final rank = a.requiredPotentialRank - b.requiredPotentialRank;
    return rank != 0 ? rank : _comparePriority(a, b);
  });
  if (sorted.isEmpty) {
    return TalentCard(
      key: key,
      name: '',
      baseDescriptionSegments: const [],
      conditionLabel: '',
    );
  }
  final base = sorted.firstWhere(
    (talent) => talent.requiredPotentialRank == 0,
    orElse: () => sorted.first,
  );
  final diff = buildPotentialDiffDisplay(
    candidates: sorted,
    keyPrefix: key,
    getPotentialLabel: (rank) =>
        i18n.t('operatorDetail.labels.potentialValue', {'value': rank + 1}),
    getPotentialIcon: (rank) => potentialIconAsset(rank + 1),
  );
  return TalentCard(
    key: key,
    name: base.name,
    baseDescriptionSegments: diff.baseDescriptionSegments,
    conditionLabel: _conditionLabel(i18n, base.elite, base.level),
    conditionElite: base.elite,
    conditionLevel: base.level,
    basePotentialLabel: diff.basePotentialLabel,
    potentialVariants: diff.potentialVariants,
  );
}

List<PotentialItem> buildPotentials(OperatorDetail operator, NexusI18n i18n) {
  return [
    for (final potential in operator.potentials)
      PotentialItem(
        key: '${potential.rank}-${potential.description}',
        rankLabel: i18n.t(
          'operatorDetail.labels.potentialStage',
          {'rank': potential.rank},
        ),
        iconAsset: potentialIconAsset(potential.rank),
        description: potential.description,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Skills
// ---------------------------------------------------------------------------

/// Where a skill table row comes from.
enum SkillRowKind {
  /// SP cost, initial SP and duration.
  base,

  /// A value the skill description shows; [SkillComparisonRow.label] is
  /// the description's wording around it with [skillValueSlot] in its place.
  described,

  /// A blackboard value the description does not mention, labelled with its
  /// raw key.
  internal,
}

/// Marks where the value sits in a [SkillRowKind.described] label.
const skillValueSlot = '▢';

class SkillComparisonRow {
  SkillComparisonRow({
    required this.key,
    required this.label,
    required this.values,
    this.kind = SkillRowKind.base,
  });

  final String key;
  final String label;
  final List<String> values;
  final SkillRowKind kind;
}

/// The values a skill level's description can refer to: its blackboard plus
/// the level's own duration (`{duration}`).
List<OperatorBlackboardEntry> skillLevelBlackboard(OperatorSkillLevel level) {
  if (findBlackboardEntry(level.blackboard, 'duration') != null) {
    return level.blackboard;
  }
  return [
    ...level.blackboard,
    OperatorBlackboardEntry(key: 'duration', value: level.duration.toDouble()),
  ];
}

final _placeholderInText = RegExp(r'\{([^{}]+)\}');
final _markupTag = RegExp(r'<[^<>]*>');
// A backslash too: some CN texts carry a literal `\n`.
final _clauseBreak = RegExp(r'[,，.。;；:：!！?？、\n\\()（）\[\]【】「」]');

/// English words that carry no meaning on their own in a short label; they
/// do not count towards the two words kept (`Stun them for ▢ seconds`).
const _fillerWords = {
  'a',
  'an',
  'and',
  'by',
  'for',
  'it',
  'its',
  'of',
  'or',
  'the',
  'them',
  'then',
  'to',
  'up',
  'with',
};
final _letter = RegExp(r'\p{L}', unicode: true);

/// Rows of the skill level table: base values, then the values the
/// description shows (in reading order, formatted as the description shows
/// them), then the internal values it does not mention.
List<SkillComparisonRow> buildSkillComparisonRows(
  OperatorSkill? skill,
  NexusI18n i18n,
) {
  if (skill == null || skill.levels.isEmpty) {
    return const [];
  }
  final levels = skill.levels;

  final rows = <SkillComparisonRow>[
    SkillComparisonRow(
      key: 'spCost',
      label: i18n.t('rd.operators.skill.spCost'),
      values: [for (final level in levels) '${level.spCost}'],
    ),
    SkillComparisonRow(
      key: 'initialSp',
      label: i18n.t('rd.operators.skill.initialSp'),
      values: [for (final level in levels) '${level.initialSp}'],
    ),
    SkillComparisonRow(
      key: 'duration',
      label: i18n.t('rd.operators.skill.duration'),
      values: [
        for (final level in levels)
          level.duration > 0 ? i18n.secondsValue(level.duration) : '–',
      ],
    ),
  ];

  // Placeholders in reading order, the highest level's wording first.
  final described = <String, (BlackboardPlaceholder, String)>{};
  for (final level in levels.reversed) {
    final text = level.description.replaceAll(_markupTag, '');
    for (final match in _placeholderInText.allMatches(text)) {
      final placeholder = BlackboardPlaceholder.parse(match.group(1)!);
      final id = placeholder.key.toLowerCase();
      if (placeholder.key.isEmpty || described.containsKey(id)) {
        continue;
      }
      // `{duration}` is the base duration row unless the blackboard has one.
      if (id == 'duration' &&
          findBlackboardEntry(level.blackboard, 'duration') == null) {
        continue;
      }
      described[id] = (placeholder, slotLabel(text, match.start, match.end));
    }
  }

  final usedLabels = <String>{};
  for (final MapEntry(key: id, value: (placeholder, label))
      in described.entries) {
    final values = [
      for (final level in levels)
        switch (findBlackboardEntry(skillLevelBlackboard(level), id)) {
          final entry? => formatBlackboardValue(entry, placeholder) ?? '-',
          null => '-',
        },
    ];
    if (values.every((value) => value == '-')) {
      continue;
    }
    rows.add(
      SkillComparisonRow(
        key: id,
        label: usedLabels.add(label) ? label : '$label · ${placeholder.key}',
        values: values,
        kind: SkillRowKind.described,
      ),
    );
  }

  final internal = <String, String>{};
  for (final level in levels) {
    for (final entry in level.blackboard) {
      final key = entry.key.trim();
      final id = key.toLowerCase();
      if (key.isNotEmpty && !described.containsKey(id)) {
        internal.putIfAbsent(id, () => key);
      }
    }
  }
  for (final MapEntry(key: id, value: key) in internal.entries) {
    rows.add(
      SkillComparisonRow(
        key: id,
        label: key,
        values: [
          for (final level in levels)
            switch (findBlackboardEntry(level.blackboard, id)) {
              final entry? => formatBlackboardValue(entry) ?? '-',
              null => '-',
            },
        ],
        kind: SkillRowKind.internal,
      ),
    );
  }
  return rows;
}

/// Short label for the placeholder at [start]..[end] of [text] (markup
/// removed): the words just before it in its clause, [skillValueSlot], and
/// the text glued after it. `2회차부터 공격력 +{atk:0%}, 무한 지속` gives
/// `2회차부터 공격력 +▢`; `주변의 적 {max_target}명에게` gives `주변의 적 ▢명에게`.
/// Spaced languages keep two words, unspaced ones (CN, JP) eight characters.
@visibleForTesting
String slotLabel(String text, int start, int end) {
  bool stops(String char) => _clauseBreak.hasMatch(char);

  var from = start;
  while (from > 0 && !stops(text[from - 1]) && text[from - 1] != '}') {
    from--;
  }
  var before = text.substring(from, start);
  // Right after another placeholder: drop the word glued to it.
  if (from > 0 && text[from - 1] == '}') {
    final space = before.indexOf(' ');
    before = space == -1 ? '' : before.substring(space + 1);
  }
  before = _lastWords(before.trimLeft());

  // Unspaced text (CN, JP) keeps only the unit after the value (`秒`, `名`).
  final clauseEnd = text.indexOf(_clauseBreak, end);
  final unspaced = !text
      .substring(from, clauseEnd < 0 ? text.length : clauseEnd)
      .contains(' ');
  var to = end;
  while (to < text.length &&
      to - end < (unspaced ? 1 : 6) &&
      !stops(text[to]) &&
      text[to] != ' ' &&
      text[to] != '{') {
    to++;
  }
  var after = text.substring(end, to);
  if (before.trim().isEmpty) {
    // The clause starts with the value (`{prob} 확률로 ...`): words after it.
    var stop = end;
    while (stop < text.length && !stops(text[stop]) && text[stop] != '{') {
      stop++;
    }
    after = _firstWords(text.substring(end, stop));
  } else if (after.isEmpty && !unspaced && text.startsWith(' ', end)) {
    // `for {t} seconds`, `deals {x} Physical`: the unit is the next word.
    final next = RegExp(r' [^ ,.;:!?()\[\]{}\n\\]{1,12}').matchAsPrefix(
      text,
      end,
    );
    final word = next?.group(0) ?? '';
    after = _fillerWords.contains(word.trim().toLowerCase()) ? '' : word;
  }
  return '$before$skillValueSlot$after'.trim();
}

String _lastWords(String text) {
  if (!text.trim().contains(' ')) {
    final chars = text.trim().runes.toList();
    final tail = String.fromCharCodes(
      chars.length <= 8 ? chars : chars.sublist(chars.length - 8),
    );
    return text.endsWith(' ') ? '$tail ' : tail;
  }
  final words = text.split(' ').where((word) => word.isNotEmpty).toList();
  final kept = <String>[];
  var lettered = 0;
  var letters = 0;
  for (final word in words.reversed) {
    kept.insert(0, word);
    if (_letter.hasMatch(word) && !_fillerWords.contains(word.toLowerCase())) {
      lettered++;
      letters += word.length;
    }
    // Two words, unless they are short (`가능 수` takes `저지` too).
    if ((lettered >= 2 && letters >= 5) || lettered >= 3 || kept.length >= 5) {
      break;
    }
  }
  // A one-letter connective in front (`후 공격력`, `및 방어력`) adds nothing.
  if (kept.length > 1 &&
      kept.first.length == 1 &&
      _letter.hasMatch(kept.first) &&
      lettered > 1) {
    kept.removeAt(0);
  }
  final joined = kept.join(' ');
  return text.endsWith(' ') ? '$joined ' : joined;
}

String _firstWords(String text) {
  final trimmed = text.trimLeft();
  final lead = text.substring(0, text.length - trimmed.length);
  if (!trimmed.contains(' ')) {
    final chars = trimmed.runes.toList();
    return lead +
        String.fromCharCodes(chars.length <= 8 ? chars : chars.sublist(0, 8));
  }
  return lead +
      trimmed.split(' ').where((word) => word.isNotEmpty).take(2).join(' ');
}

// ---------------------------------------------------------------------------
// Attack ranges
// ---------------------------------------------------------------------------

class RangeMatrixCell {
  const RangeMatrixCell({required this.isActive, required this.isOrigin});

  final bool isActive;
  final bool isOrigin;
}

class RangeMatrix {
  const RangeMatrix({
    required this.id,
    required this.columnCount,
    required this.rows,
  });

  final String id;
  final int columnCount;
  final List<List<RangeMatrixCell>> rows;
}

RangeMatrix? buildRangeMatrix(OperatorRange? range) {
  if (range == null) {
    return null;
  }
  final active = {for (final grid in range.grids) '${grid.row}:${grid.col}'};
  final allRows = [0, ...range.grids.map((grid) => grid.row)];
  final allCols = [0, ...range.grids.map((grid) => grid.col)];
  final minRow = allRows.reduce((a, b) => a < b ? a : b);
  final maxRow = allRows.reduce((a, b) => a > b ? a : b);
  final minCol = allCols.reduce((a, b) => a < b ? a : b);
  final maxCol = allCols.reduce((a, b) => a > b ? a : b);

  return RangeMatrix(
    id: range.id,
    columnCount: maxCol - minCol + 1,
    rows: [
      for (var row = maxRow; row >= minRow; row--)
        [
          for (var col = minCol; col <= maxCol; col++)
            RangeMatrixCell(
              isActive: active.contains('$row:$col'),
              isOrigin: row == 0 && col == 0,
            ),
        ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

class ModuleStatBonusItem {
  const ModuleStatBonusItem({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;
}

class ModulePotentialVariant {
  const ModulePotentialVariant(this.variant, this.rangeMatrix);

  final TalentPotentialVariant variant;
  final RangeMatrix? rangeMatrix;
}

class ModuleEffectCandidate {
  const ModuleEffectCandidate({
    required this.key,
    required this.title,
    required this.conditionElite,
    required this.conditionLevel,
    required this.baseDescriptionSegments,
    this.basePotentialLabel,
    this.potentialVariants = const [],
    this.rangeMatrix,
  });

  final String key;
  final String title;
  final int conditionElite;
  final int conditionLevel;
  final List<RichTextSegment> baseDescriptionSegments;
  final String? basePotentialLabel;
  final List<ModulePotentialVariant> potentialVariants;
  final RangeMatrix? rangeMatrix;
}

class ModuleEffectPart {
  const ModuleEffectPart({
    required this.target,
    required this.traitGroups,
    required this.talentGroups,
  });

  final String target;
  final List<ModuleEffectCandidate> traitGroups;
  final List<ModuleEffectCandidate> talentGroups;
}

String humanizeModuleKey(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .join(' ');
}

const _moduleStatKeyMap = {
  'max_hp': 'hp',
  'atk': 'atk',
  'def': 'def',
  'magic_resistance': 'magic_res',
  'magic_res': 'magic_res',
  'cost': 'cost',
  'block_cnt': 'block_cnt',
  'respawn_time': 'respawn_time',
  'attack_interval': 'attack_interval',
  'hp_recovery_per_sec': 'hp_recovery_per_sec',
};

String _prefixModuleValue(String value) {
  return value.startsWith('-') || value.startsWith('+') ? value : '+$value';
}

String _formatModuleStatValue(OperatorBlackboardEntry entry) {
  final valueStr = entry.valueStr?.trim();
  if (valueStr != null && valueStr.isNotEmpty) {
    return _prefixModuleValue(valueStr);
  }
  final value = entry.value ?? 0;
  final display = value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return _prefixModuleValue(display);
}

List<ModuleStatBonusItem> buildModuleStatBonuses(
  OperatorModuleBattlePhase? phase,
  NexusI18n i18n,
) {
  if (phase == null) {
    return const [];
  }
  return [
    for (final entry in phase.attributeBlackboard)
      if (entry.key.trim().isNotEmpty)
        ModuleStatBonusItem(
          key: entry.key.trim(),
          label: _moduleStatKeyMap[entry.key.trim()] != null
              ? i18n.statLabel(_moduleStatKeyMap[entry.key.trim()]!)
              : humanizeModuleKey(entry.key.trim()),
          value: _formatModuleStatValue(entry),
        ),
  ];
}

String moduleTargetLabel(String target, NexusI18n i18n) {
  return switch (target) {
    'TRAIT' => i18n.t('operatorDetail.labels.traitOverride'),
    'TALENT' => i18n.t('operatorDetail.labels.talentOverride'),
    _ => humanizeModuleKey(target),
  };
}

final _talpuTagPattern = RegExp(r'<@ba\.talpu>.*?</>');
final _anyTagPattern = RegExp(r'<[^>]+>');
final _whitespacePattern = RegExp(r'\s+');

String descriptionStructureSignature(String description) {
  return description
      .replaceAll(_talpuTagPattern, '')
      .replaceAll(_anyTagPattern, '')
      .replaceAll(displayValueTokenPattern, '#')
      .replaceAll(_whitespacePattern, ' ')
      .trim();
}

List<ModuleEffectPart> buildModuleEffectParts(
  OperatorModuleBattlePhase? phase,
  NexusI18n i18n,
) {
  if (phase == null) {
    return const [];
  }
  return [
    for (final part in phase.parts)
      ModuleEffectPart(
        target: part.target,
        traitGroups: _mergeTraitGroups(part.traitCandidates, i18n),
        talentGroups: _mergeTalentGroups(part.talentCandidates, i18n),
      ),
  ]
      .where(
        (part) => part.traitGroups.isNotEmpty || part.talentGroups.isNotEmpty,
      )
      .toList();
}

List<ModuleEffectCandidate> _mergeTraitGroups(
  List<OperatorTraitCandidate> candidates,
  NexusI18n i18n,
) {
  final groups = <String, List<OperatorTraitCandidate>>{};
  for (final candidate in candidates) {
    final key = [
      candidate.elite,
      candidate.level,
      descriptionStructureSignature(candidate.description),
    ].join(':');
    groups.putIfAbsent(key, () => []).add(candidate);
  }
  return [
    for (final entry
        in stableSorted(groups.entries, (a, b) => a.key.compareTo(b.key)))
      _buildModuleEffectCandidate(
        entry.key,
        i18n.t('operatorDetail.labels.traitOverride'),
        entry.value,
        i18n,
      ),
  ];
}

List<ModuleEffectCandidate> _mergeTalentGroups(
  List<OperatorTalentCandidate> candidates,
  NexusI18n i18n,
) {
  final groups = <String, List<OperatorTalentCandidate>>{};
  for (final candidate in candidates) {
    final key = [
      candidate.elite,
      candidate.level,
      candidate.name?.trim() ?? '',
      descriptionStructureSignature(candidate.description),
    ].join(':');
    groups.putIfAbsent(key, () => []).add(candidate);
  }
  return [
    for (final entry
        in stableSorted(groups.entries, (a, b) => a.key.compareTo(b.key)))
      _buildModuleEffectCandidate(
        entry.key,
        (entry.value.first.name?.trim().isNotEmpty ?? false)
            ? entry.value.first.name!.trim()
            : i18n.t('operatorDetail.labels.talentOverride'),
        entry.value,
        i18n,
      ),
  ];
}

ModuleEffectCandidate _buildModuleEffectCandidate(
  String key,
  String title,
  List<OperatorTraitCandidate> candidates,
  NexusI18n i18n,
) {
  final sorted = stableSorted(candidates, (a, b) {
    final rank = a.requiredPotentialRank - b.requiredPotentialRank;
    if (rank != 0) {
      return rank;
    }
    final elite = a.elite - b.elite;
    return elite != 0 ? elite : a.level - b.level;
  });
  if (sorted.isEmpty) {
    return ModuleEffectCandidate(
      key: key,
      title: title,
      conditionElite: 0,
      conditionLevel: 1,
      baseDescriptionSegments: const [],
    );
  }
  final base = sorted.firstWhere(
    (candidate) => candidate.requiredPotentialRank == 0,
    orElse: () => sorted.first,
  );
  final rangeByRank = <int, RangeMatrix?>{
    for (final candidate in sorted)
      candidate.requiredPotentialRank: buildRangeMatrix(candidate.range),
  };
  final diff = buildPotentialDiffDisplay(
    candidates: sorted,
    keyPrefix: key,
    getPotentialLabel: (rank) =>
        i18n.t('operatorDetail.labels.potentialValue', {'value': rank + 1}),
    getPotentialIcon: (rank) => potentialIconAsset(rank + 1),
  );
  return ModuleEffectCandidate(
    key: key,
    title: title,
    conditionElite: base.elite,
    conditionLevel: base.level,
    baseDescriptionSegments: diff.baseDescriptionSegments,
    basePotentialLabel: diff.basePotentialLabel,
    potentialVariants: [
      for (final variant in diff.potentialVariants)
        ModulePotentialVariant(
          variant,
          variant.hasFallback
              ? rangeByRank[variant.requiredPotentialRank]
              : null,
        ),
    ],
    rangeMatrix: buildRangeMatrix(base.range),
  );
}
