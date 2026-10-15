import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'operator_detail_view_model.dart';
import 'operator_detail_widgets.dart';
import 'operators_common.dart';

/// Modules panel of the operator detail: module picker pills, the selected
/// module card (equip icon, unlock / trust chips, stage segmented control),
/// stat bonuses and trait/talent override cards.
class OperatorModuleSection extends StatefulWidget {
  const OperatorModuleSection({
    required this.modules,
    required this.i18n,
    this.typeIcons = const {},
    this.equipIcons = const {},
    this.onTermTap,
    this.compact = false,
    super.key,
  });

  final List<OperatorModule> modules;
  final NexusI18n i18n;

  /// Resolved `moduleType` icon files keyed by `uniEquipId`.
  final Map<String, File> typeIcons;

  /// Resolved `moduleEquip` icon files keyed by `uniEquipId`.
  final Map<String, File> equipIcons;
  final TermTapCallback? onTermTap;

  /// Phone sizes (44px segments, smaller range cells).
  final bool compact;

  @override
  State<OperatorModuleSection> createState() => _OperatorModuleSectionState();
}

class _OperatorModuleSectionState extends State<OperatorModuleSection> {
  String? _selectedModuleId;
  int _selectedLevel = 1;

  OperatorModule? get _selectedModule {
    final modules = widget.modules;
    for (final module in modules) {
      if (module.uniEquipId == _selectedModuleId) {
        return module;
      }
    }
    return modules.isEmpty ? null : modules.first;
  }

  /// Mirrors the page's `watchEffect`: keep the battle level when the new
  /// module has it, otherwise fall back to its first phase.
  int _effectiveLevel(OperatorModule? module) {
    final phases = module?.battlePhases ?? const [];
    if (phases.any((phase) => phase.equipLevel == _selectedLevel)) {
      return _selectedLevel;
    }
    return phases.isEmpty ? 1 : phases.first.equipLevel;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final module = _selectedModule;
    final level = _effectiveLevel(module);
    final phases = module?.battlePhases ?? const <OperatorModuleBattlePhase>[];
    OperatorModuleBattlePhase? phase;
    for (final candidate in phases) {
      if (candidate.equipLevel == level) {
        phase = candidate;
        break;
      }
    }
    phase ??= phases.isEmpty ? null : phases.first;

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
              for (final entry in widget.modules)
                _ModulePill(
                  module: entry,
                  selected: entry.uniEquipId == module?.uniEquipId,
                  icon: widget.typeIcons[entry.uniEquipId],
                  onTap: () => setState(() {
                    _selectedModuleId = entry.uniEquipId;
                    _selectedLevel = level;
                  }),
                ),
            ],
          ),
        ),
        if (module == null)
          Text(i18n.t('operatorDetail.states.noModules'), style: RdText.muted)
        else
          _ModuleCard(
            module: module,
            phase: phase,
            level: level,
            equipIcon: widget.equipIcons[module.uniEquipId],
            i18n: i18n,
            compact: widget.compact,
            onTermTap: widget.onTermTap,
            onLevelChanged: (value) => setState(() => _selectedLevel = value),
          ),
      ],
    );
  }
}

/// Selected-state decoration shared by the module pills and skill buttons.
BoxDecoration detailToggleDecoration({
  required bool selected,
  required bool hovered,
  required double radius,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected ? const Color(0x7381D6FF) : RdColors.white8,
    ),
    color: selected ? null : (hovered ? RdColors.line2 : RdColors.soft2),
    gradient: selected
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x4059B5FF), Color(0x298AF8FF)],
          )
        : null,
  );
}

/// Pressable surface with the [detailToggleDecoration] states.
class DetailToggle extends StatefulWidget {
  const DetailToggle({
    required this.selected,
    required this.radius,
    required this.onTap,
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    super.key,
  });

  final bool selected;
  final double radius;
  final VoidCallback onTap;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  State<DetailToggle> createState() => _DetailToggleState();
}

class _DetailToggleState extends State<DetailToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: detailToggleDecoration(
              selected: widget.selected,
              hovered: _hovered,
              radius: widget.radius,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ModulePill extends StatelessWidget {
  const _ModulePill({
    required this.module,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final OperatorModule module;
  final bool selected;
  final File? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = module.typeIcon.toUpperCase();
    return DetailToggle(
      selected: selected,
      radius: RdRadii.pill,
      height: 48,
      padding: const EdgeInsets.fromLTRB(7, 0, 16, 0),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xBF060A12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon != null
                ? Image.file(icon!, fit: BoxFit.contain)
                : Text(
                    label.isEmpty ? '' : label.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: RdColors.cyan,
                    ),
                  ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 192),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDBE4F5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.phase,
    required this.level,
    required this.equipIcon,
    required this.i18n,
    required this.compact,
    required this.onLevelChanged,
    this.onTermTap,
  });

  final OperatorModule module;
  final OperatorModuleBattlePhase? phase;
  final int level;
  final File? equipIcon;
  final NexusI18n i18n;
  final bool compact;
  final ValueChanged<int> onLevelChanged;
  final TermTapCallback? onTermTap;

  /// Trust needed for the selected stage (`unlockFavorPercents`).
  int? get _favorPercent {
    final value = module.unlockFavorPercents?['$level'] ?? 0;
    return value > 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final phase = this.phase;
    final statBonuses = buildModuleStatBonuses(phase, i18n);
    final effectParts = buildModuleEffectParts(phase, i18n);
    final unlockElite = elitePhaseFromCode(module.unlockEvolvePhase);
    final favor = _favorPercent;
    const cautionLabel = TextStyle(color: Color(0xCCFFD6C0));
    final rangeCell = compact ? 26.0 : 28.0;
    final typeLabel = module.typeIcon.toUpperCase();

    return RdInset.section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            module.uniEquipName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: RdColors.text,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xD1070A12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: RdColors.white8),
                ),
                child: equipIcon != null
                    ? Image.file(equipIcon!, fit: BoxFit.contain)
                    : Text(
                        typeLabel.isEmpty ? '' : typeLabel.substring(0, 1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: RdColors.cyan,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (module.isSpecialEquip)
                      DetailChip.text(
                        i18n.t('operatorDetail.labels.specialModule'),
                        caution: true,
                      ),
                    if (module.missionList.isNotEmpty)
                      DetailChip.text(
                        i18n.t('operatorDetail.labels.missionUnlocked'),
                        caution: true,
                      ),
                    DetailChip(
                      caution: true,
                      children: [
                        Text(
                          i18n.t('operatorDetail.labels.unlockCondition'),
                          style: cautionLabel,
                        ),
                        if (unlockElite != null)
                          EliteIcon(unlockElite, height: 18),
                        Text('Lv.${module.unlockLevel}'),
                      ],
                    ),
                    if (favor != null)
                      DetailChip(
                        caution: true,
                        children: [
                          Text(
                            i18n.t('operatorDetail.labels.favorCondition'),
                            style: cautionLabel,
                          ),
                          Text('$favor%'),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (module.battlePhases.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                RdHeading(
                  i18n.t('operatorDetail.labels.moduleStage'),
                  fontSize: 14,
                  color: RdColors.heading,
                ),
                OpSegmented<int>(
                  key: const ValueKey('module-stage'),
                  semanticLabel: i18n.t('operatorDetail.labels.moduleStage'),
                  height: compact ? 44 : 40,
                  value: level,
                  segments: [
                    for (final entry in module.battlePhases)
                      OpSegment(entry.equipLevel, '${entry.equipLevel}'),
                  ],
                  onChanged: onLevelChanged,
                ),
              ],
            ),
          if (phase == null)
            Text(
              i18n.t('operatorDetail.states.noModuleDetails'),
              style: RdText.muted,
            )
          else ...[
            if (statBonuses.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  RdHeading(
                    i18n.t('operatorDetail.labels.moduleStatBonus'),
                    fontSize: 14,
                    color: RdColors.heading,
                  ),
                  RdAutoGrid(
                    minTileWidth: 110,
                    gap: 10,
                    children: [
                      for (final bonus in statBonuses)
                        Container(
                          key: ValueKey('bonus-${bonus.key}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x09FFFFFF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              Text(
                                bonus.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: RdColors.secondary2,
                                ),
                              ),
                              Text(
                                bonus.value,
                                style: RdText.mono(
                                  fontSize: 17,
                                  color: const Color(0xFFEFF6FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            if (effectParts.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  RdHeading(
                    i18n.t('operatorDetail.labels.moduleEffects'),
                    fontSize: 14,
                    color: RdColors.heading,
                  ),
                  for (final part in effectParts)
                    Container(
                      key: ValueKey(
                        '${module.uniEquipId}-${phase.equipLevel}-${part.target}',
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x09FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          DetailHeaderWrap(
                            children: [
                              Text(
                                moduleTargetLabel(part.target, i18n),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: RdColors.text,
                                ),
                              ),
                              DetailChip.text(
                                '${i18n.t('operatorDetail.labels.moduleStage')} ${phase.equipLevel}',
                              ),
                            ],
                          ),
                          for (final candidate in [
                            ...part.traitGroups,
                            ...part.talentGroups,
                          ])
                            ModuleCandidateCard(
                              candidate: candidate,
                              rangeCell: rangeCell,
                              onTermTap: onTermTap,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (statBonuses.isEmpty && effectParts.isEmpty)
              Text(
                i18n.t('operatorDetail.states.noModuleDetails'),
                style: RdText.muted,
              ),
          ],
        ],
      ),
    );
  }
}

/// Trait/talent override card of a module stage.
class ModuleCandidateCard extends StatelessWidget {
  const ModuleCandidateCard({
    required this.candidate,
    this.rangeCell = 28,
    this.onTermTap,
    super.key,
  });

  final ModuleEffectCandidate candidate;
  final double rangeCell;
  final TermTapCallback? onTermTap;

  @override
  Widget build(BuildContext context) {
    final variants = candidate.potentialVariants;
    return RdInset.section(
      key: ValueKey(candidate.key),
      color: RdColors.white3,
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          DetailHeaderWrap(
            children: [
              Text(
                candidate.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RdColors.text,
                ),
              ),
              ConditionChip(
                elite: candidate.conditionElite,
                level: candidate.conditionLevel,
              ),
              if (candidate.basePotentialLabel != null)
                DetailChip.text(candidate.basePotentialLabel!),
            ],
          ),
          RichTextContent(
            segments: candidate.baseDescriptionSegments,
            style: detailBodyStyle,
            onTermTap: onTermTap,
          ),
          if (candidate.rangeMatrix != null)
            RangeGrid(candidate.rangeMatrix!, cell: rangeCell),
          if (variants.any((entry) => entry.variant.hasFallback))
            PotentialVariantList(
              variants: [for (final entry in variants) entry.variant],
              ranges: {
                for (final entry in variants)
                  entry.variant.key: entry.rangeMatrix,
              },
              rangeCell: rangeCell,
              onTermTap: onTermTap,
            ),
        ],
      ),
    );
  }
}
