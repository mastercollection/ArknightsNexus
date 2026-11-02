import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/app_failure.dart';
import '../../domain/item.dart';
import '../../domain/stage.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/item_service.dart';
import '../../services/operator_service.dart';
import '../../ui/nexus_ui.dart' show ItemIcon;
import '../../ui/redesign/rd_widgets.dart';
import '../shared/number_format.dart';
import 'stage_enemy_view.dart';
import 'stage_format.dart';
import 'stage_player.dart';
import 'stages_screen.dart';

/// One stage: its briefing and rewards, the map with the enemies' routes and
/// a playback of the spawn schedule, and the enemies' stats. The map comes
/// from the stage's level file, fetched when the page opens.
class StageDetailScreen extends ConsumerStatefulWidget {
  const StageDetailScreen({required this.stageId, super.key});

  static const routeName = 'stage-detail';

  final String stageId;

  @override
  ConsumerState<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends ConsumerState<StageDetailScreen> {
  List<StageSummary> _stages = const [];
  StageSummary? _stage;
  StageDetail? _detail;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _missingLevel = false;
  String _levelError = '';
  Map<String, ItemEntry> _items = const {};
  Map<String, String> _operatorNames = const {};
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(regionProvider, (_, __) => unawaited(_load()));
    ref.listenManual(dataRevisionProvider, (_, __) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void didUpdateWidget(StageDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageId != widget.stageId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final region = ref.read(regionProvider);
    final service = ref.read(stageServiceProvider);
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _missingLevel = false;
      _levelError = '';
      _detail = null;
    });
    try {
      final stages = await service.listStages(region);
      final stage =
          stages.where((stage) => stage.stageId == widget.stageId).firstOrNull;
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _stages = stages;
        _stage = stage;
      });
      if (stage == null) {
        return;
      }
      unawaited(_loadRewardTargets(token, stage));
      try {
        final detail = await service.stageDetail(region, stage.stageId);
        if (mounted && token == _loadToken) {
          setState(() => _detail = detail);
        }
      } on MissingLevelFailure {
        if (mounted && token == _loadToken) {
          setState(() => _missingLevel = true);
        }
      } catch (error, stackTrace) {
        ref
            .read(appLoggerProvider)
            .warning('stage level load failed', error, stackTrace);
        if (mounted && token == _loadToken) {
          setState(() => _levelError = '$error');
        }
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('stage load failed', error, stackTrace);
      if (mounted && token == _loadToken) {
        setState(() => _errorMessage = '$error');
      }
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// The items and operators the rewards link to.
  Future<void> _loadRewardTargets(int token, StageSummary stage) async {
    if (stage.rewards.isEmpty) {
      return;
    }
    final region = ref.read(regionProvider);
    try {
      final items = await ref
          .read(itemServiceProvider)
          .listItems(ItemQuery(region: region));
      final operators = await ref
          .read(operatorServiceProvider)
          .listOperators(OperatorQuery(region: region));
      if (mounted && token == _loadToken) {
        setState(() {
          _items = {for (final item in items) item.itemId: item};
          _operatorNames = {
            for (final operator in operators) operator.id: operator.name,
          };
        });
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('stage reward names load failed', error, stackTrace);
    }
  }

  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/stages');
    }
  }

  void _openVariant(StageSummary stage) {
    context.replace(StagesScreen.detailPath(stage.stageId));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final stage = _stage;

    final Widget content;
    if (_errorMessage.isNotEmpty) {
      content = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('stages.loadFailed'),
        message: _errorMessage,
      );
    } else if (stage == null) {
      content = _isLoading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : RdStatePanel(
              kind: RdStateKind.empty,
              layout: RdStateLayout.left,
              title: i18n.t('stages.empty'),
              action: RdButton(
                label: i18n.t('stages.backToList'),
                variant: RdButtonVariant.primary,
                onPressed: _backToList,
              ),
            );
    } else {
      content = _body(i18n, stage, compact);
    }

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            i18n: i18n,
            stage: stage,
            variants: stage == null ? const [] : stageVariants(stage, _stages),
            onBack: _backToList,
            onVariant: _openVariant,
          ),
          Expanded(
            child: ListView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                  : const EdgeInsets.fromLTRB(32, 24, 32, 32),
              children: [content],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(NexusI18n i18n, StageSummary stage, bool compact) {
    final detail = _detail;
    final Widget mapCard;
    if (detail != null) {
      mapCard = _Section(
        title: i18n.t('stages.map'),
        child: StagePlayer(detail: detail, code: stage.code, i18n: i18n),
      );
    } else if (_missingLevel || stage.levelId == null) {
      mapCard = RdNotice(
        text: i18n.t(
          stage.levelId == null ? 'stages.storyOnly' : 'stages.noLevel',
        ),
      );
    } else if (_levelError.isNotEmpty) {
      mapCard = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('stages.levelFailed'),
        message: _levelError,
        action: RdButton(
          label: i18n.t('stages.retry'),
          onPressed: () => unawaited(_load()),
        ),
      );
    } else {
      mapCard = const _Section(
        title: '',
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final info = _InfoCard(i18n: i18n, stage: stage, detail: detail);
    final rewards = stage.rewards.isEmpty
        ? null
        : _RewardsCard(
            i18n: i18n,
            rewards: stage.rewards,
            items: _items,
            operatorNames: _operatorNames,
          );
    final enemies = detail == null || detail.enemies.isEmpty
        ? null
        : _EnemiesCard(i18n: i18n, detail: detail);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 680, child: mapCard),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        info,
                        if (rewards != null) ...[
                          const SizedBox(height: 16),
                          rewards,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (enemies != null) ...[const SizedBox(height: 16), enemies],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mapCard,
            const SizedBox(height: 14),
            info,
            if (enemies != null) ...[const SizedBox(height: 14), enemies],
            if (rewards != null) ...[const SizedBox(height: 14), rewards],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.i18n,
    required this.stage,
    required this.variants,
    required this.onBack,
    required this.onVariant,
  });

  final NexusI18n i18n;
  final StageSummary? stage;
  final List<StageSummary> variants;
  final VoidCallback onBack;
  final ValueChanged<StageSummary> onVariant;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final stage = this.stage;
    final chips = stage == null || stage.levelId == null
        ? const <Widget>[]
        : [
            RdPill(label: i18n.t('stages.ap', {'ap': stage.apCost})),
            if (stage.dangerLevel != null && stage.dangerLevel != '-')
              RdPill(
                label: i18n.t('stages.recommended', {
                  'level': stage.dangerLevel,
                }),
              ),
          ];
    final variantSwitch = variants.length < 2 || stage == null
        ? null
        : SizedBox(
            width: variants.length * (compact ? 84.0 : 88.0),
            child: RdSegmented<String>(
              semanticLabel: i18n.t('stages.difficulty'),
              height: compact ? 40 : 36,
              segments: [
                for (final variant in variants)
                  RdSegment(
                    variant.stageId,
                    i18n.t(StageDifficulty.of(variant)!.labelKey),
                  ),
              ],
              selected: stage.stageId,
              onChanged: (id) =>
                  onVariant(variants.firstWhere((v) => v.stageId == id)),
            ),
          );
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (stage != null) ...[
          // Codes like `MN-EX-1` are long: they shrink with the name rather
          // than push it out.
          Flexible(
            child: Text(
              stage.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RdText.mono(
                fontSize: compact ? 20 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              stage?.name ?? i18n.t('stages.title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: compact ? RdText.mobileTitle : RdText.pageTitle,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(4, 6, 16, 12)
          : const EdgeInsets.fromLTRB(24, 16, 32, 16),
      decoration: const BoxDecoration(
        color: RdColors.surface1,
        border: Border(bottom: BorderSide(color: RdColors.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RdIconButton(
                        icon: Icons.chevron_left,
                        tooltip: i18n.t('stages.backToList'),
                        filled: false,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: title),
                    ],
                  ),
                  if (stage?.zoneName != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(stage!.zoneName!, style: RdText.small),
                    ),
                  if (chips.isNotEmpty || variantSwitch != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...chips,
                          if (variantSwitch != null) variantSwitch,
                        ],
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  RdIconButton(
                    icon: Icons.chevron_left,
                    tooltip: i18n.t('stages.backToList'),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 14),
                  // The chips go under the title, so a long code or name
                  // only shortens the title.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (stage?.zoneName != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  stage!.zoneName!,
                                  style: RdText.muted,
                                ),
                              ),
                            ...chips,
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (variantSwitch != null) ...[
                    const SizedBox(width: 16),
                    variantSwitch,
                  ],
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: RdText.sectionTitle),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.i18n,
    required this.stage,
    required this.detail,
  });

  final NexusI18n i18n;
  final StageSummary stage;
  final StageDetail? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final description = stage.description;
    final values = detail == null
        ? const <(String, String)>[]
        : [
            ('stages.characterLimit', '${detail.options.characterLimit}'),
            ('stages.lifePoint', '${detail.options.maxLifePoint}'),
            (
              'stages.enemyTotal',
              '${detail.enemies.fold(0, (sum, enemy) => sum + enemy.count)}',
            ),
            ('stages.initialCost', '${detail.options.initialCost}'),
            ('stages.maxCost', '${detail.options.maxCost}'),
            ('stages.lastSpawn', formatStageTime(detail.lastSpawnTime)),
          ];
    return _Section(
      title: i18n.t('stages.info'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (values.isNotEmpty) ...[
            RdAutoGrid(
              columns: 3,
              gap: 8,
              children: [
                for (final (key, value) in values)
                  RdInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i18n.t(key), style: RdText.small),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: RdText.mono(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (description != null && description.trim().isNotEmpty)
            Text(
              plainStageText(description),
              style: RdText.body.copyWith(height: 1.55),
            ),
        ],
      ),
    );
  }
}

class _RewardsCard extends StatelessWidget {
  const _RewardsCard({
    required this.i18n,
    required this.rewards,
    required this.items,
    required this.operatorNames,
  });

  final NexusI18n i18n;
  final List<StageReward> rewards;
  final Map<String, ItemEntry> items;
  final Map<String, String> operatorNames;

  String _label(StageReward reward) {
    final drop = i18n.t('stages.drop.${reward.dropType}');
    return reward.occPercent == 'ALWAYS' || reward.dropType == 'ONCE'
        ? drop
        : '$drop · ${i18n.t('stages.occ.${reward.occPercent}')}';
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: i18n.t('stages.rewards'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reward in rewards) _reward(context, reward),
        ],
      ),
    );
  }

  Widget _reward(BuildContext context, StageReward reward) {
    final item = items[reward.id];
    final operatorName =
        reward.type == 'CHAR' ? operatorNames[reward.id] : null;
    final name = item?.name ?? operatorName ?? reward.id;
    final String? target = item != null
        ? '/items/${reward.id}'
        : operatorName != null
            ? '/operators/${reward.id}'
            : null;
    final icon = operatorName != null
        ? RdPortrait(charId: reward.id, name: name, size: 36, radius: 8)
        : ItemIcon(
            itemId: reward.id,
            iconId: item?.iconId,
            name: name,
            size: 36,
          );
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  color: target == null ? RdColors.text : RdColors.link,
                ),
              ),
              const SizedBox(height: 2),
              Text(_label(reward), style: RdText.small),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: target != null,
      label:
          target == null ? null : i18n.t('stages.openReward', {'name': name}),
      child: Material(
        color: RdColors.surface3,
        borderRadius: BorderRadius.circular(RdRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.control),
          onTap: target == null ? null : () => context.push(target),
          child: content,
        ),
      ),
    );
  }
}

/// The stage's enemies: a table (PC) or cards (phones), and the details of
/// the chosen one (archive text, abilities, the stats the table leaves out).
class _EnemiesCard extends StatefulWidget {
  const _EnemiesCard({required this.i18n, required this.detail});

  final NexusI18n i18n;
  final StageDetail detail;

  @override
  State<_EnemiesCard> createState() => _EnemiesCardState();
}

class _EnemiesCardState extends State<_EnemiesCard> {
  /// The enemy whose details show; on phones an empty id folds them all.
  String? _selected;

  NexusI18n get i18n => widget.i18n;

  List<StageEnemy> get _enemies =>
      [...widget.detail.enemies]..sort((a, b) => b.count.compareTo(a.count));

  String _range(EnemyStats stats) => stats.rangeRadius <= 0
      ? i18n.t('stages.melee')
      : formatStageDecimal(stats.rangeRadius);

  @override
  Widget build(BuildContext context) {
    final enemies = _enemies;
    final total = enemies.fold(0, (sum, enemy) => sum + enemy.count);
    final compact = context.rdLayout == RdLayout.compact;
    final selectedId = _selected ?? enemies.first.enemyId;
    final selected = enemies.firstWhere(
      (enemy) => enemy.enemyId == selectedId,
      orElse: () => enemies.first,
    );
    return _Section(
      title: i18n.t('stages.enemies'),
      trailing: Text(
        i18n.t('stages.enemiesSummary', {
          'kinds': enemies.length,
          'count': total,
        }),
        style: RdText.small,
      ),
      child: compact
          ? _cards(enemies)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _table(enemies, selected),
                const SizedBox(height: 8),
                Text(i18n.t('stages.enemyHint'), style: RdText.caption),
                const SizedBox(height: 12),
                StageEnemyDetails(i18n: i18n, enemy: selected),
              ],
            ),
    );
  }

  void _select(StageEnemy enemy) => setState(() => _selected = enemy.enemyId);

  Widget _table(List<StageEnemy> enemies, StageEnemy selected) {
    const numeric = TextAlign.right;
    final mono = RdText.mono(fontSize: 13);
    Widget head(String key, {TextAlign align = TextAlign.left}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(i18n.t(key), textAlign: align, style: RdText.small),
        );
    Widget cell(StageEnemy enemy, Widget child) => TableRowInkWell(
          onTap: () => _select(enemy),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: child,
          ),
        );
    Widget number(StageEnemy enemy, String text) =>
        cell(enemy, Text(text, textAlign: numeric, style: mono));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 960),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {1: FlexColumnWidth(2.6)},
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: RdColors.border)),
              ),
              children: [
                head('stages.col.index'),
                head('stages.col.enemy'),
                head('stages.col.level'),
                head('stages.col.count', align: numeric),
                head('stages.col.hp', align: numeric),
                head('stages.col.atk', align: numeric),
                head('stages.col.def', align: numeric),
                head('stages.col.res', align: numeric),
                head('stages.col.block', align: numeric),
                head('stages.col.speed', align: numeric),
                head('stages.col.range', align: numeric),
              ],
            ),
            for (final enemy in enemies)
              TableRow(
                decoration: BoxDecoration(
                  color: enemy.enemyId == selected.enemyId
                      ? RdColors.accentSoft
                      : null,
                  border: const Border(
                    bottom: BorderSide(color: RdColors.hairline),
                  ),
                ),
                children: [
                  cell(
                    enemy,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RdPill(label: enemy.enemyIndex ?? '-'),
                    ),
                  ),
                  cell(
                    enemy,
                    Row(
                      children: [
                        StageEnemyIcon(enemy: enemy, size: 32),
                        const SizedBox(width: 10),
                        Flexible(child: Text(enemy.name, style: RdText.body)),
                      ],
                    ),
                  ),
                  cell(
                    enemy,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StageLevelPill(
                        i18n: i18n,
                        levelType: enemy.levelType,
                      ),
                    ),
                  ),
                  number(enemy, '${enemy.count}'),
                  number(enemy, formatWholeNumber(enemy.stats.maxHp)),
                  number(enemy, formatWholeNumber(enemy.stats.atk)),
                  number(enemy, formatWholeNumber(enemy.stats.def)),
                  number(enemy, formatStageWhole(enemy.stats.magicResistance)),
                  number(enemy, '${enemy.stats.blockCnt}'),
                  number(enemy, formatStageDecimal(enemy.stats.moveSpeed)),
                  number(enemy, _range(enemy.stats)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cards(List<StageEnemy> enemies) {
    Widget stat(String key, String value) => Row(
          children: [
            Expanded(child: Text(i18n.t(key), style: RdText.small)),
            Text(value, style: RdText.mono(fontSize: 12)),
          ],
        );
    final open = _selected ?? '';
    return Column(
      children: [
        for (final enemy in enemies)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: RdColors.surface3,
              borderRadius: BorderRadius.circular(RdRadii.inner),
              child: InkWell(
                borderRadius: BorderRadius.circular(RdRadii.inner),
                onTap: () => setState(
                  () => _selected = open == enemy.enemyId ? '' : enemy.enemyId,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          StageEnemyIcon(enemy: enemy, size: 36),
                          const SizedBox(width: 10),
                          if (enemy.enemyIndex != null) ...[
                            RdPill(label: enemy.enemyIndex!),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              enemy.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RdColors.text,
                              ),
                            ),
                          ),
                          if (enemy.levelType != 'NORMAL') ...[
                            StageLevelPill(
                              i18n: i18n,
                              levelType: enemy.levelType,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '×${enemy.count}',
                            style: RdText.mono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      RdAutoGrid(
                        columns: 3,
                        gap: 6,
                        children: [
                          stat(
                            'stages.col.hp',
                            formatWholeNumber(enemy.stats.maxHp),
                          ),
                          stat(
                            'stages.col.atk',
                            formatWholeNumber(enemy.stats.atk),
                          ),
                          stat(
                            'stages.col.def',
                            formatWholeNumber(enemy.stats.def),
                          ),
                          stat(
                            'stages.col.res',
                            formatStageWhole(enemy.stats.magicResistance),
                          ),
                          stat(
                            'stages.col.speed',
                            formatStageDecimal(enemy.stats.moveSpeed),
                          ),
                          stat('stages.col.range', _range(enemy.stats)),
                        ],
                      ),
                      if (open == enemy.enemyId) ...[
                        const SizedBox(height: 12),
                        StageEnemyDetails(
                          i18n: i18n,
                          enemy: enemy,
                          inset: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
