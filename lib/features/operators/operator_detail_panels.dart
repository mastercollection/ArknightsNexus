import 'package:flutter/material.dart';

import '../../domain/operator.dart';
import '../../domain/rich_text_segment.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/rich_description.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view_model.dart';
import 'operator_detail_widgets.dart';
import 'operator_module_section.dart';
import 'operator_skill_table.dart';
import 'operators_common.dart';

/// Section panels of the operator detail (one per tab).

String _eliteLabel(NexusI18n i18n, int elite) =>
    '${i18n.t('operatorDetail.labels.elite')} $elite';

Widget? _eliteLeading(int elite) {
  return rdEliteAsset(elite) == null ? null : RdEliteIcon(elite, size: 20);
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// Elite segmented control, level slider with steppers and the stat cards
/// (`getOperatorStats` interpolation between the phase's min and max).
class OperatorStatsPanel extends StatelessWidget {
  const OperatorStatsPanel({
    required this.operator,
    required this.i18n,
    required this.elite,
    required this.level,
    required this.onEliteChanged,
    required this.onLevelChanged,
    required this.compact,
    super.key,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final int elite;
  final int level;
  final ValueChanged<int> onEliteChanged;
  final ValueChanged<int> onLevelChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final maxLevel =
        elite < operator.eliteCaps.length ? operator.eliteCaps[elite] : 1;
    final cards = buildStatCards(operator, elite, level, i18n);
    const fieldLabel = TextStyle(fontSize: 13, color: RdColors.secondary);

    final eliteField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(i18n.t('operatorDetail.labels.elite'), style: fieldLabel),
        RdSegmented<int>(
          key: const ValueKey('stats-elite'),
          semanticLabel: i18n.t('operatorDetail.labels.elite'),
          height: compact ? 44 : 40,
          selected: elite,
          segments: [
            for (var i = 0; i < operator.eliteCaps.length; i++)
              RdSegment(i, _eliteLabel(i18n, i), leading: _eliteLeading(i)),
          ],
          onChanged: onEliteChanged,
        ),
      ],
    );
    final levelField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(i18n.t('operatorDetail.labels.level'), style: fieldLabel),
        SizedBox(
          height: 48,
          child: OpRangeControl(
            key: const ValueKey('stats-level'),
            value: level,
            min: 1,
            max: maxLevel,
            onChanged: onLevelChanged,
            buttonSize: compact ? 44 : 40,
            semanticLabel: i18n.t('operatorDetail.labels.level'),
            decreaseTooltip: i18n.t('rd.operators.detail.levelDown'),
            increaseTooltip: i18n.t('rd.operators.detail.levelUp'),
            readout: Text.rich(
              TextSpan(
                text: '$level',
                children: [
                  TextSpan(
                    text: '/$maxLevel',
                    style: const TextStyle(color: RdColors.text3),
                  ),
                ],
              ),
              style: RdText.mono(),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // `flex: 1 1 220px` wrap: side by side when both fit.
            if (constraints.maxWidth >= 220 * 2 + 14) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 14,
                children: [
                  Expanded(child: eliteField),
                  Expanded(child: levelField),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [eliteField, levelField],
            );
          },
        ),
        RdAutoGrid(
          minTileWidth: compact ? 120 : 140,
          gap: 10,
          children: [
            for (final card in cards)
              Container(
                key: ValueKey('stat-${card.key}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: opPanelFill,
                  borderRadius: BorderRadius.circular(RdRadii.card),
                  border: Border.all(color: RdColors.white8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      i18n.statLabel(card.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: RdColors.secondary2,
                      ),
                    ),
                    Text(card.value, style: RdText.mono(fontSize: 21)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Abilities
// ---------------------------------------------------------------------------

/// Elite tab, attack range, traits and talents of the selected phase.
class OperatorAbilitiesPanel extends StatelessWidget {
  const OperatorAbilitiesPanel({
    required this.operator,
    required this.i18n,
    required this.eliteTab,
    required this.onEliteTabChanged,
    required this.onTermTap,
    required this.compact,
    super.key,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final int eliteTab;
  final ValueChanged<int> onEliteTabChanged;
  final TermTapCallback onTermTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final range = buildRangeMatrix(
      eliteTab < operator.stats.length ? operator.stats[eliteTab].range : null,
    );
    final traits = buildTraits(operator, eliteTab, i18n);
    final talents = buildTalents(operator, eliteTab, i18n);
    final cell = compact ? 26.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (operator.eliteCaps.isNotEmpty)
          RdSegmented<int>(
            key: const ValueKey('abilities-elite'),
            semanticLabel: i18n.t('operatorDetail.labels.elite'),
            height: compact ? 44 : 40,
            selected: eliteTab,
            segments: [
              for (var i = 0; i < operator.eliteCaps.length; i++)
                RdSegment(i, 'E$i', leading: _eliteLeading(i)),
            ],
            onChanged: onEliteTabChanged,
          ),
        if (range != null)
          RdInset.section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                DetailHeaderWrap(
                  children: [
                    RdHeading(
                      i18n.t('operatorDetail.labels.attackRange'),
                      color: RdColors.heading,
                    ),
                    DetailChip(
                      children: [
                        if (rdEliteAsset(eliteTab) != null)
                          RdEliteIcon(eliteTab)
                        else
                          Text(
                            i18n.t(
                              'operatorDetail.labels.eliteShort',
                              {'elite': eliteTab},
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                RangeGrid(range, cell: cell),
              ],
            ),
          ),
        RdHeading(
          i18n.t('operatorDetail.labels.trait'),
          description: i18n.t('operatorDetail.descriptions.trait'),
          color: RdColors.heading,
        ),
        for (final trait in traits)
          RdInset.section(
            key: ValueKey('trait-${trait.key}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                DetailHeaderWrap(
                  children: [
                    Text(
                      i18n.t('operatorDetail.labels.trait'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: RdColors.text,
                      ),
                    ),
                    ConditionChip(
                      elite: trait.conditionElite,
                      level: trait.conditionLevel,
                      label: trait.conditionLabel,
                    ),
                    if (trait.potentialLabel != null)
                      DetailChip.text(trait.potentialLabel!),
                  ],
                ),
                RichTextContent(
                  segments: trait.descriptionSegments,
                  style: detailBodyStyle,
                  onTermTap: onTermTap,
                ),
              ],
            ),
          ),
        if (operator.talents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RdHeading(
              i18n.t('operatorDetail.labels.talent'),
              description: i18n.t('operatorDetail.descriptions.talent'),
              color: RdColors.heading,
            ),
          ),
          if (talents.isNotEmpty)
            for (final talent in talents)
              _TalentCardView(
                talent: talent,
                onTermTap: onTermTap,
                rangeCell: cell,
              )
          else
            Text(
              i18n.t('operatorDetail.states.noTalentForCurrentStage'),
              style: const TextStyle(fontSize: 14, color: RdColors.muted),
            ),
        ],
      ],
    );
  }
}

class _TalentCardView extends StatelessWidget {
  const _TalentCardView({
    required this.talent,
    required this.onTermTap,
    required this.rangeCell,
  });

  final TalentCard talent;
  final TermTapCallback onTermTap;
  final double rangeCell;

  @override
  Widget build(BuildContext context) {
    return RdInset.section(
      key: ValueKey('talent-${talent.key}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          DetailHeaderWrap(
            children: [
              Text(
                talent.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RdColors.text,
                ),
              ),
              ConditionChip(
                elite: talent.conditionElite,
                level: talent.conditionLevel,
                label: talent.conditionLabel,
              ),
              if (talent.basePotentialLabel != null)
                DetailChip.text(talent.basePotentialLabel!),
            ],
          ),
          RichTextContent(
            segments: talent.baseDescriptionSegments,
            style: detailBodyStyle,
            onTermTap: onTermTap,
          ),
          if (talent.potentialVariants.any((variant) => variant.hasFallback))
            PotentialVariantList(
              variants: talent.potentialVariants,
              rangeCell: rangeCell,
              onTermTap: onTermTap,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Potentials
// ---------------------------------------------------------------------------

class OperatorPotentialsPanel extends StatelessWidget {
  const OperatorPotentialsPanel({required this.potentials, super.key});

  final List<PotentialItem> potentials;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final potential in potentials)
          Container(
            key: ValueKey('potential-${potential.key}'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: RdColors.white3,
              borderRadius: BorderRadius.circular(RdRadii.card),
            ),
            child: Row(
              spacing: 12,
              children: [
                Image.asset(
                  potential.iconAsset,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  semanticLabel: potential.rankLabel,
                ),
                Text(
                  potential.rankLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
                Expanded(
                  child: Text(
                    potential.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: RdColors.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

/// Thin wrapper so the module section restarts with each operator.
class OperatorModulesPanel extends StatelessWidget {
  const OperatorModulesPanel({
    required this.operator,
    required this.i18n,
    required this.typeIcons,
    required this.equipIcons,
    required this.onTermTap,
    required this.compact,
    super.key,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final Map<String, ImageProvider> typeIcons;
  final Map<String, ImageProvider> equipIcons;
  final TermTapCallback onTermTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OperatorModuleSection(
      key: ValueKey('modules-${operator.id}'),
      modules: operator.modules,
      i18n: i18n,
      typeIcons: typeIcons,
      equipIcons: equipIcons,
      onTermTap: onTermTap,
      compact: compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Skills
// ---------------------------------------------------------------------------

/// Skill picker, the selected skill's summary at the display level, the
/// level slider and the level comparison (range + table).
class OperatorSkillsPanel extends StatelessWidget {
  const OperatorSkillsPanel({
    required this.operator,
    required this.i18n,
    required this.selectedSkill,
    required this.selectedLevel,
    required this.skillIcons,
    required this.onSkillSelected,
    required this.onLevelChanged,
    required this.onTermTap,
    required this.compact,
    super.key,
  });

  final OperatorDetail operator;
  final NexusI18n i18n;
  final OperatorSkill? selectedSkill;
  final int selectedLevel;
  final Map<String, ImageProvider> skillIcons;
  final ValueChanged<String> onSkillSelected;
  final ValueChanged<int> onLevelChanged;
  final TermTapCallback onTermTap;
  final bool compact;

  String _masteryLabel(int rank) =>
      i18n.t('rd.operators.detail.mastery', {'value': rank});

  @override
  Widget build(BuildContext context) {
    final skill = selectedSkill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            spacing: 10,
            children: [
              for (final entry in operator.skills)
                _SkillButton(
                  skill: entry,
                  icon: skillIcons[entry.id],
                  selected: entry.id == skill?.id,
                  onTap: () => onSkillSelected(entry.id),
                ),
            ],
          ),
        ),
        if (skill != null) ..._skillDetail(skill),
      ],
    );
  }

  /// Mastery icon for levels 8-10, else the level text.
  Widget _levelChip(int level, {required bool selectedText}) {
    final asset = rdMasteryAsset(level);
    return DetailChip(
      children: [
        if (asset != null)
          RdMasteryIcon(level, semanticLabel: _masteryLabel(level - 7))
        else
          Text(
            selectedText
                ? i18n.t('operatorDetail.labels.selectedLevel', {
                    'level': level,
                  })
                : 'Lv.$level',
          ),
      ],
    );
  }

  List<Widget> _skillDetail(OperatorSkill skill) {
    OperatorSkillLevel? levelInfo;
    for (final entry in skill.levels) {
      if (entry.level == selectedLevel) {
        levelInfo = entry;
        break;
      }
    }
    levelInfo ??= skill.levels.isEmpty ? null : skill.levels.first;
    final description = levelInfo == null
        ? const <RichTextSegment>[]
        : parseRichDescription(levelInfo.description, levelInfo.blackboard);
    final range = buildRangeMatrix(levelInfo?.range);
    final rows = buildSkillComparisonRows(skill);
    final maxLevel = skill.levels.isEmpty ? 1 : skill.levels.length;
    final shownLevel = levelInfo?.level ?? selectedLevel;

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          DetailHeaderWrap(
            children: [
              Text(
                skill.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: RdColors.text,
                ),
              ),
              DetailChip(
                caution: true,
                children: [
                  Text(i18n.t('operatorDetail.labels.unlockCondition')),
                  if (rdEliteAsset(skill.unlockElite) != null)
                    RdEliteIcon(skill.unlockElite, size: 18),
                  Text(
                    i18n.t(
                      'operatorDetail.labels.conditionLevel',
                      {'level': skill.unlockLevel},
                    ),
                  ),
                ],
              ),
              if (levelInfo != null)
                _levelChip(levelInfo.level, selectedText: true),
            ],
          ),
          RichTextContent(
            segments: description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.75,
              color: RdColors.text2,
            ),
            onTermTap: onTermTap,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DetailChip.text(i18n.skillRecovery(skill.recoveryType)),
              DetailChip.text(i18n.skillActivation(skill.activationType)),
            ],
          ),
        ],
      ),
      RdInset.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            RdHeading(
              i18n.t('operatorDetail.labels.displayLevel'),
              description:
                  i18n.t('operatorDetail.descriptions.skillDisplayLevel'),
              color: RdColors.heading,
            ),
            OpRangeControl(
              key: const ValueKey('skill-level'),
              value: selectedLevel,
              min: 1,
              max: maxLevel,
              onChanged: onLevelChanged,
              buttonSize: compact ? 44 : 40,
              semanticLabel: i18n.t('rd.operators.detail.skillLevel'),
              decreaseTooltip: i18n.t('rd.operators.detail.skillLevelDown'),
              increaseTooltip: i18n.t('rd.operators.detail.skillLevelUp'),
              readout: rdMasteryAsset(shownLevel) != null
                  ? RdMasteryIcon(
                      shownLevel,
                      size: 26,
                      semanticLabel: _masteryLabel(shownLevel - 7),
                    )
                  : Text('Lv.$shownLevel', style: RdText.mono()),
            ),
          ],
        ),
      ),
      RdInset.section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            RdHeading(
              i18n.t('operatorDetail.labels.levelComparison'),
              description:
                  i18n.t('operatorDetail.descriptions.skillLevelComparison'),
              color: RdColors.heading,
            ),
            if (range != null)
              RdInset(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    DetailHeaderWrap(
                      children: [
                        RdHeading(
                          i18n.t('operatorDetail.labels.skillRange'),
                          fontSize: 14,
                          color: RdColors.heading,
                        ),
                        if (levelInfo != null)
                          _levelChip(levelInfo.level, selectedText: false),
                      ],
                    ),
                    RangeGrid(range, cell: compact ? 26 : 28),
                  ],
                ),
              ),
            OperatorSkillTable(
              key: ValueKey('skill-table-${skill.id}'),
              skill: skill,
              rows: rows,
              selectedLevel: selectedLevel,
              itemLabel: i18n.t('operatorDetail.labels.item'),
              compact: compact,
              masteryLabel: _masteryLabel,
            ),
          ],
        ),
      ),
    ];
  }
}

class _SkillButton extends StatelessWidget {
  const _SkillButton({
    required this.skill,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final OperatorSkill skill;
  final ImageProvider? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: skill.name,
      waitDuration: const Duration(milliseconds: 400),
      child: DetailToggle(
        key: ValueKey('skill-${skill.id}'),
        selected: selected,
        radius: RdRadii.control,
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(6),
        semanticLabel: skill.name,
        onTap: onTap,
        child: icon != null
            ? Image(
                image: icon!,
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                semanticLabel: skill.name,
              )
            : Text(
                skill.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: RdColors.text,
                ),
              ),
      ),
    );
  }
}
