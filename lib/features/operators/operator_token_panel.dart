import 'package:flutter/material.dart';

import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/rich_description.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_panels.dart';
import 'operator_detail_widgets.dart';
import 'operator_module_section.dart';

/// The summoner's skills that deploy [token], as `(slot, skill)` with the
/// slot counted from 1 (`S2`); empty when the summon comes with every skill,
/// whether no skill names it or all of them do.
List<(int, OperatorSkill)> tokenSkillSlots(
  OperatorDetail operator,
  OperatorToken token,
) {
  final slots = <(int, OperatorSkill)>[
    for (var index = 0; index < operator.skills.length; index++)
      if (token.skillIds.contains(operator.skills[index].id))
        (index + 1, operator.skills[index]),
  ];
  return slots.length == operator.skills.length ? const [] : slots;
}

/// The summons tab: a picker when there are several, then the selected
/// summon's header (portrait, name, the skills it belongs to, description)
/// and the operator panels reused for it: stats, abilities and skills.
///
/// The summon follows the operator's elite, level and skill display level
/// (a summon is deployed at its summoner's), each limited to what the
/// summon has; changing them here changes them for the operator too.
class OperatorTokensPanel extends StatelessWidget {
  const OperatorTokensPanel({
    required this.operator,
    required this.token,
    required this.i18n,
    required this.elite,
    required this.level,
    required this.selectedSkill,
    required this.skillLevel,
    required this.skillIcons,
    required this.onTokenSelected,
    required this.onEliteChanged,
    required this.onLevelChanged,
    required this.onSkillSelected,
    required this.onSkillLevelChanged,
    required this.onTermTap,
    required this.compact,
    super.key,
  });

  /// The summoner.
  final OperatorDetail operator;

  /// The selected summon, one of [operator]'s.
  final OperatorToken token;
  final NexusI18n i18n;

  /// Elite and level, already limited to the summon's caps.
  final int elite;
  final int level;

  /// The selected skill of the summon (null when it has none) and its
  /// display level, already limited to the skill's levels.
  final OperatorSkill? selectedSkill;
  final int skillLevel;
  final Map<String, ImageProvider> skillIcons;
  final ValueChanged<String> onTokenSelected;
  final ValueChanged<int> onEliteChanged;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<String> onSkillSelected;
  final ValueChanged<int> onSkillLevelChanged;
  final TermTapCallback onTermTap;
  final bool compact;

  String _skillLabel(int slot) =>
      i18n.t('rd.operators.tokens.skillSlot', {'slot': slot});

  @override
  Widget build(BuildContext context) {
    final detail = token.detail;
    final abilities = OperatorAbilitiesPanel.hasContent(
      detail,
      elite,
      i18n,
      archetypeTrait: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (operator.tokens.length > 1)
          Semantics(
            container: true,
            label: i18n.t('rd.operators.tokens.picker'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in operator.tokens)
                  _TokenChip(
                    token: entry,
                    slots: tokenSkillSlots(operator, entry),
                    slotLabel: _skillLabel,
                    selected: entry.id == token.id,
                    onTap: () => onTokenSelected(entry.id),
                  ),
              ],
            ),
          ),
        KeyedSubtree(
          key: ValueKey('token-${token.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              _TokenHeader(
                token: token,
                slots: tokenSkillSlots(operator, token),
                slotLabel: _skillLabel,
                i18n: i18n,
                compact: compact,
                onTermTap: onTermTap,
              ),
              if (detail.eliteCaps.isNotEmpty) ...[
                _heading(i18n.t('operatorDetail.sections.stats')),
                OperatorStatsPanel(
                  operator: detail,
                  i18n: i18n,
                  elite: elite,
                  level: level,
                  compact: compact,
                  onEliteChanged: onEliteChanged,
                  onLevelChanged: onLevelChanged,
                ),
              ],
              if (abilities) ...[
                _heading(i18n.t('operatorDetail.sections.abilities')),
                OperatorAbilitiesPanel(
                  operator: detail,
                  i18n: i18n,
                  eliteTab: elite,
                  compact: compact,
                  showEliteTabs: false,
                  archetypeTrait: false,
                  onEliteTabChanged: onEliteChanged,
                  onTermTap: onTermTap,
                ),
              ],
              if (detail.skills.isNotEmpty) ...[
                _heading(i18n.t('operatorDetail.sections.skills')),
                OperatorSkillsPanel(
                  operator: detail,
                  i18n: i18n,
                  selectedSkill: selectedSkill,
                  selectedLevel: skillLevel,
                  skillIcons: skillIcons,
                  compact: compact,
                  unlockBadges: {
                        for (final skill in detail.skills) skill.unlockElite,
                      }.length >
                      1,
                  onSkillSelected: onSkillSelected,
                  onLevelChanged: onSkillLevelChanged,
                  onTermTap: onTermTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Sub-section title, a step above the panels' own headings.
  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: RdColors.text,
          ),
        ),
      ),
    );
  }
}

/// `S2` chip of a summon tied to that skill; the skill name as tooltip.
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.skillName});

  final String label;
  final String skillName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: skillName,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: RdColors.accentSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: RdColors.accentText,
          ),
        ),
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.token,
    required this.slots,
    required this.slotLabel,
    required this.selected,
    required this.onTap,
  });

  final OperatorToken token;
  final List<(int, OperatorSkill)> slots;
  final String Function(int slot) slotLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = token.detail.name;
    // The toggle centres its child, which fills the width it is given; the
    // chip is as wide as its content instead.
    return IntrinsicWidth(
      child: DetailToggle(
        key: ValueKey('token-chip-${token.id}'),
        selected: selected,
        radius: RdRadii.control,
        height: 44,
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        semanticLabel: [
          name,
          for (final (slot, skill) in slots) '${slotLabel(slot)} ${skill.name}',
        ].join(', '),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              RdPortrait(charId: token.id, name: name, size: 32, radius: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? RdColors.text : RdColors.text2,
                  ),
                ),
              ),
              for (final (slot, skill) in slots)
                _SlotChip(label: slotLabel(slot), skillName: skill.name),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portrait, name, the summoner's skills that deploy the summon and its
/// description (with term links).
class _TokenHeader extends StatelessWidget {
  const _TokenHeader({
    required this.token,
    required this.slots,
    required this.slotLabel,
    required this.i18n,
    required this.compact,
    required this.onTermTap,
  });

  final OperatorToken token;
  final List<(int, OperatorSkill)> slots;
  final String Function(int slot) slotLabel;
  final NexusI18n i18n;
  final bool compact;
  final TermTapCallback onTermTap;

  @override
  Widget build(BuildContext context) {
    final detail = token.detail;
    final description = detail.archetypeDescription.trim();
    final portrait = compact ? 64.0 : 72.0;
    return RdInset.section(
      key: const ValueKey('token-header'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          RdPortrait(
            charId: detail.id,
            name: detail.name,
            size: portrait,
            radius: 10,
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: portrait),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      detail.name,
                      style: TextStyle(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w700,
                        color: RdColors.text,
                      ),
                    ),
                  ),
                  if (slots.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (slot, skill) in slots)
                          DetailChip.text(
                            i18n.t('rd.operators.tokens.forSkill', {
                              'slot': slotLabel(slot),
                              'skill': skill.name,
                            }),
                          ),
                      ],
                    ),
                  if (description.isNotEmpty)
                    RichTextContent(
                      segments: parseRichDescription(description),
                      style: detailBodyStyle,
                      onTermTap: onTermTap,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
