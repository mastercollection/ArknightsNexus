import 'package:flutter/material.dart';

import '../../data_sources/image_source.dart';
import '../../domain/stage.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import '../../widgets/cached_image.dart';
import '../shared/number_format.dart';
import 'stage_format.dart';

/// `1.0`, `0.65`: one decimal at least, two at most.
String formatStageDecimal(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(1)
    : '${(value * 100).round() / 100}';

/// `20`, `0.5`: no decimals for whole numbers.
String formatStageWhole(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : formatStageDecimal(value);

/// Everything the stage knows of one enemy: archive text, the stats the
/// table leaves out, abilities, skills and talents. The enemy table and the
/// playback show the same panel, from the same [StageEnemy].
class StageEnemyDetails extends StatelessWidget {
  const StageEnemyDetails({
    required this.i18n,
    required this.enemy,
    this.inset = true,
    this.onClose,
    super.key,
  });

  final NexusI18n i18n;
  final StageEnemy enemy;

  /// Draws its own surface and header (the PC panel, the playback); a
  /// phone card already has both.
  final bool inset;

  /// Adds a close button to the header.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final stats = enemy.stats;
    final description = enemy.description;
    final values = <(String, String)>[
      (
        'stages.damage',
        enemy.damageType.isEmpty
            ? '-'
            : enemy.damageType
                .map((type) => i18n.t('stages.damage.$type'))
                .join(' · '),
      ),
      ('stages.col.motion', i18n.t('stages.motion.${stats.motion}')),
      (
        'stages.col.interval',
        i18n.t('stages.seconds', {
          'value': formatStageDecimal(stats.baseAttackTime),
        }),
      ),
      ('stages.col.weight', '${stats.massLevel}'),
      ('stages.col.lifeReduce', '${stats.lifePointReduce}'),
      (
        'stages.col.hpRegen',
        stats.hpRecoveryPerSec <= 0
            ? '-'
            : formatStageDecimal(stats.hpRecoveryPerSec),
      ),
      (
        'stages.immune',
        stats.immunities.isEmpty
            ? i18n.t('stages.immune.none')
            : stats.immunities
                .map((name) => i18n.t('stages.immune.$name'))
                .join(' · '),
      ),
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inset) ...[
          Row(
            children: [
              StageEnemyIcon(enemy: enemy, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enemy.name, style: RdText.sectionTitle),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (enemy.enemyIndex != null) enemy.enemyIndex!,
                        i18n.t('stages.levelType.${enemy.levelType}'),
                        '×${enemy.count}',
                      ].join(' · '),
                      style: RdText.small,
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                RdIconButton(
                  icon: Icons.close,
                  tooltip: i18n.t('stages.closeEnemy'),
                  filled: false,
                  size: 40,
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (inset) ...[
          _Stats(i18n: i18n, stats: stats),
          const SizedBox(height: 12),
        ],
        if (description != null && description.trim().isNotEmpty) ...[
          Text(
            plainStageText(description),
            style: RdText.secondary.copyWith(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final (key, value) in values) _Value(i18n.t(key), value),
          ],
        ),
        const SizedBox(height: 14),
        Text(i18n.t('stages.abilities'), style: RdText.small),
        const SizedBox(height: 4),
        if (enemy.abilities.isEmpty)
          Text(i18n.t('stages.noAbilities'), style: RdText.muted)
        else
          for (final ability in enemy.abilities)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${plainStageText(ability)}',
                style: RdText.body.copyWith(fontSize: 13, height: 1.45),
              ),
            ),
        if (stats.skills.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(i18n.t('stages.skills'), style: RdText.small),
          const SizedBox(height: 6),
          for (final skill in stats.skills)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _Skill(i18n: i18n, skill: skill),
            ),
        ],
        if (stats.talents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(i18n.t('stages.talents'), style: RdText.small),
          const SizedBox(height: 6),
          _Values(values: stats.talents),
        ],
        if (stats.skills.isNotEmpty || stats.talents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(i18n.t('stages.rawValuesNote'), style: RdText.caption),
        ],
      ],
    );
    if (!inset) {
      return body;
    }
    return RdInset(padding: const EdgeInsets.all(16), child: body);
  }
}

/// The table's stats, for the panel the playback opens.
class _Stats extends StatelessWidget {
  const _Stats({required this.i18n, required this.stats});

  final NexusI18n i18n;
  final EnemyStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('stages.col.hp', formatWholeNumber(stats.maxHp)),
      ('stages.col.atk', formatWholeNumber(stats.atk)),
      ('stages.col.def', formatWholeNumber(stats.def)),
      ('stages.col.res', formatStageWhole(stats.magicResistance)),
      ('stages.col.block', '${stats.blockCnt}'),
      ('stages.col.speed', formatStageDecimal(stats.moveSpeed)),
      (
        'stages.col.range',
        stats.rangeRadius <= 0
            ? i18n.t('stages.melee')
            : formatStageDecimal(stats.rangeRadius),
      ),
    ];
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        for (final (key, value) in values) _Value(i18n.t(key), value),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: RdText.small),
        const SizedBox(height: 2),
        Text(value, style: RdText.mono(fontSize: 13)),
      ],
    );
  }
}

class _Skill extends StatelessWidget {
  const _Skill({required this.i18n, required this.skill});

  final NexusI18n i18n;
  final EnemySkill skill;

  @override
  Widget build(BuildContext context) {
    final timing = [
      i18n.t('stages.skill.cooldown', {
        'value': formatStageWhole(skill.cooldown),
      }),
      if (skill.initCooldown != skill.cooldown)
        i18n.t('stages.skill.first', {
          'value': formatStageWhole(skill.initCooldown),
        }),
      if (skill.spCost > 0) i18n.t('stages.skill.sp', {'value': skill.spCost}),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RdColors.white3,
        borderRadius: BorderRadius.circular(RdRadii.chip),
        border: Border.all(color: RdColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                skill.key,
                style: RdText.mono(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(timing, style: RdText.small),
            ],
          ),
          if (skill.values.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Values(values: skill.values),
          ],
        ],
      ),
    );
  }
}

/// `key value` pairs of a skill or the talents, as the data has them.
class _Values extends StatelessWidget {
  const _Values({required this.values});

  final List<EnemyValue> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: RdColors.surface2,
              borderRadius: BorderRadius.circular(RdRadii.chip),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key} ',
                    style: const TextStyle(color: RdColors.muted),
                  ),
                  TextSpan(
                    text: entry.value != null
                        ? formatStageWhole(entry.value!)
                        : entry.text ?? '',
                  ),
                ],
              ),
              style: RdText.mono(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class StageEnemyIcon extends StatelessWidget {
  const StageEnemyIcon({required this.enemy, required this.size, super.key});

  final StageEnemy enemy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        enemy.enemyIndex ?? '',
        style: RdText.mono(fontSize: size * 0.3, color: RdColors.text2),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RdColors.portrait,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: CachedImage(
        kind: CachedImageKind.enemyIcon,
        id: enemy.enemyId,
        size: size,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.zero,
        fit: BoxFit.contain,
        placeholder: fallback,
      ),
    );
  }
}

class StageLevelPill extends StatelessWidget {
  const StageLevelPill({
    required this.i18n,
    required this.levelType,
    super.key,
  });

  final NexusI18n i18n;
  final String levelType;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (levelType) {
      'BOSS' => (RdColors.dangerFill, RdColors.dangerText),
      'ELITE' => (RdColors.warningFill, RdColors.warningText),
      _ => (RdColors.surface3, RdColors.text2),
    };
    return RdPill(
      label: i18n.t('stages.levelType.$levelType'),
      color: color,
      textColor: text,
    );
  }
}
