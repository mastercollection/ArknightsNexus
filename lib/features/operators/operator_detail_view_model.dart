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

List<TraitItem> buildTraits(
  OperatorDetail operator,
  int selectedElite,
  NexusI18n i18n,
) {
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

  if (selected.isEmpty && operator.archetypeDescription.trim().isNotEmpty) {
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

class SkillComparisonRow {
  SkillComparisonRow({
    required this.key,
    required this.label,
    required this.values,
  });

  final String key;
  final String label;
  final List<String> values;
}

String _formatMetricNumber(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
}

String _humanizeMetricKey(String value) {
  return value
      .split(RegExp('[_-]'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _metricValue(OperatorBlackboardEntry entry) {
  final valueStr = entry.valueStr?.trim();
  if (valueStr != null && valueStr.isNotEmpty) {
    return valueStr;
  }
  return entry.value == null ? '-' : _formatMetricNumber(entry.value!);
}

/// Port of `useSkillComparisonRows`.
List<SkillComparisonRow> buildSkillComparisonRows(OperatorSkill? skill) {
  if (skill == null) {
    return const [];
  }
  final count = skill.levels.length;
  final rows = <String, SkillComparisonRow>{};

  void put(String key, String label, int level, String value) {
    final row = rows.putIfAbsent(
      key,
      () => SkillComparisonRow(
        key: key,
        label: label,
        values: List.filled(count, '-'),
      ),
    );
    final index = level - 1;
    if (index >= 0 && index < row.values.length) {
      row.values[index] = value;
    }
  }

  for (final levelInfo in skill.levels) {
    put('spCost', 'SP Cost', levelInfo.level, '${levelInfo.spCost}');
    put('initialSp', 'Initial SP', levelInfo.level, '${levelInfo.initialSp}');
    put('duration', 'Duration', levelInfo.level, '${levelInfo.duration}');
    for (final entry in levelInfo.blackboard) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      put(key, _humanizeMetricKey(key), levelInfo.level, _metricValue(entry));
    }
  }
  return rows.values.toList();
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
