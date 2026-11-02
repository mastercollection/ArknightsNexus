import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/stage.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'stage_format.dart';

/// Every stage of the selected region, by category and zone: a zone list
/// beside the stage tiles on wider windows, a zone picker above a stage list
/// on phones. A search shows matches from every zone.
class StagesScreen extends ConsumerStatefulWidget {
  const StagesScreen({super.key});

  static const routeName = 'stages';

  /// The detail route of [stageId] (Challenge Mode ids carry a `#`).
  static String detailPath(String stageId) =>
      '/stages/${Uri.encodeComponent(stageId)}';

  @override
  ConsumerState<StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends ConsumerState<StagesScreen> {
  final _searchController = TextEditingController();

  List<StageSummary> _stages = const [];
  List<StageZone> _zones = const [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _loadToken = 0;

  StageCategory _category = StageCategory.main;
  final _zoneByCategory = <StageCategory, String>{};
  StageDifficulty _difficulty = StageDifficulty.normal;
  String _search = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual(regionProvider, (_, __) => unawaited(_load()));
    ref.listenManual(dataRevisionProvider, (_, __) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final stages = await ref
          .read(stageServiceProvider)
          .listStages(ref.read(regionProvider));
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _stages = stages;
        _zones = stageZones(stages);
      });
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('stage list load failed', error, stackTrace);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _stages = const [];
        _zones = const [];
        _errorMessage = '$error';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<StageZone> get _categoryZones => [
        for (final zone in _zones)
          if (zone.category == _category) zone,
      ];

  StageZone? get _zone {
    final zones = _categoryZones;
    if (zones.isEmpty) {
      return null;
    }
    final id = _zoneByCategory[_category];
    return zones.where((zone) => zone.zoneId == id).firstOrNull ?? zones.first;
  }

  void _selectZone(StageZone zone) {
    setState(() {
      _zoneByCategory[_category] = zone.zoneId;
      if (!zone.difficulties.contains(_difficulty)) {
        _difficulty = StageDifficulty.normal;
      }
    });
  }

  List<StageSummary> get _searchResults {
    final query = _search.trim().toLowerCase();
    return [
      for (final stage in _stages)
        if (StageDifficulty.of(stage) == StageDifficulty.normal &&
            (stage.code.toLowerCase().contains(query) ||
                stage.name.toLowerCase().contains(query)))
          stage,
    ].take(120).toList();
  }

  void _open(StageSummary stage) {
    context.push(StagesScreen.detailPath(stage.stageId));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final search = RdSearchField(
      controller: _searchController,
      hintText: i18n.t('stages.search'),
      height: compact ? 44 : 40,
      onChanged: (value) => setState(() => _search = value),
      onCleared: () => setState(() => _search = ''),
    );
    final categories = RdSegmented<StageCategory>(
      semanticLabel: i18n.t('stages.category'),
      height: compact ? 44 : 40,
      segments: [
        for (final category in StageCategory.values)
          RdSegment(category, i18n.t(category.labelKey)),
      ],
      selected: _category,
      onChanged: (category) => setState(() {
        _category = category;
        _difficulty = StageDifficulty.normal;
      }),
    );

    final Widget body;
    if (_isLoading && _stages.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          RdStatePanel(
            kind: RdStateKind.error,
            layout: RdStateLayout.left,
            title: i18n.t('stages.loadFailed'),
            message: _errorMessage,
          ),
        ],
      );
    } else if (_search.trim().isNotEmpty) {
      body = _StageList(
        i18n: i18n,
        stages: _searchResults,
        compact: compact,
        showZone: true,
        onOpen: _open,
      );
    } else if (compact) {
      body = _CompactZoneBody(
        i18n: i18n,
        zones: _categoryZones,
        zone: _zone,
        difficulty: _difficulty,
        onZone: _selectZone,
        onDifficulty: (difficulty) => setState(() => _difficulty = difficulty),
        onOpen: _open,
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 260,
            child: _ZoneSidebar(
              i18n: i18n,
              categories: categories,
              zones: _categoryZones,
              selected: _zone,
              onSelect: _selectZone,
            ),
          ),
          Expanded(
            child: _ZoneStages(
              i18n: i18n,
              zone: _zone,
              difficulty: _difficulty,
              onDifficulty: (difficulty) =>
                  setState(() => _difficulty = difficulty),
              onOpen: _open,
            ),
          ),
        ],
      );
    }

    return Material(
      color: RdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: i18n.t('stages.title'),
            count: _stages.isEmpty
                ? null
                : i18n.t('stages.count', {'count': _stages.length}),
            search: search,
            categories: compact ? categories : null,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.search,
    required this.categories,
  });

  final String title;
  final String? count;
  final Widget search;

  /// Shown under the search on phones; wider layouts put it in the sidebar.
  final Widget? categories;

  @override
  Widget build(BuildContext context) {
    final compact = context.rdLayout == RdLayout.compact;
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: compact ? RdText.mobileTitle : RdText.pageTitle,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 10),
          Text(count!, style: RdText.small),
        ],
      ],
    );
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.fromLTRB(32, 18, 32, 18),
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
                  titleRow,
                  const SizedBox(height: 10),
                  search,
                  if (categories != null) ...[
                    const SizedBox(height: 10),
                    categories!,
                  ],
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(child: titleRow),
                    SizedBox(
                      width: (constraints.maxWidth - 300).clamp(200.0, 360.0),
                      child: search,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ZoneSidebar extends StatelessWidget {
  const _ZoneSidebar({
    required this.i18n,
    required this.categories,
    required this.zones,
    required this.selected,
    required this.onSelect,
  });

  final NexusI18n i18n;
  final Widget categories;
  final List<StageZone> zones;
  final StageZone? selected;
  final ValueChanged<StageZone> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: RdColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: categories,
          ),
          Expanded(
            child: Semantics(
              container: true,
              label: i18n.t('stages.zones'),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: zones.length,
                itemBuilder: (context, index) {
                  final zone = zones[index];
                  final on = zone.zoneId == selected?.zoneId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      button: true,
                      selected: on,
                      child: Material(
                        color: on ? RdColors.accentSoft : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RdRadii.control),
                          side: on
                              ? const BorderSide(color: RdColors.accentLine)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(RdRadii.control),
                          onTap: () => onSelect(zone),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              zone.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    on ? FontWeight.w700 : FontWeight.w500,
                                color: RdColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySwitch extends StatelessWidget {
  const _DifficultySwitch({
    required this.i18n,
    required this.zone,
    required this.difficulty,
    required this.onChanged,
  });

  final NexusI18n i18n;
  final StageZone zone;
  final StageDifficulty difficulty;
  final ValueChanged<StageDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = zone.difficulties;
    if (available.length < 2) {
      return const SizedBox.shrink();
    }
    final shown = [
      for (final option in StageDifficulty.values)
        if (available.contains(option)) option,
    ];
    return SizedBox(
      width: shown.length * 88,
      child: RdSegmented<StageDifficulty>(
        semanticLabel: i18n.t('stages.difficulty'),
        height: context.rdLayout == RdLayout.compact ? 40 : 36,
        segments: [
          for (final option in StageDifficulty.values)
            if (available.contains(option))
              RdSegment(option, i18n.t(option.labelKey)),
        ],
        selected: difficulty,
        onChanged: onChanged,
      ),
    );
  }
}

class _ZoneStages extends StatelessWidget {
  const _ZoneStages({
    required this.i18n,
    required this.zone,
    required this.difficulty,
    required this.onDifficulty,
    required this.onOpen,
  });

  final NexusI18n i18n;
  final StageZone? zone;
  final StageDifficulty difficulty;
  final ValueChanged<StageDifficulty> onDifficulty;
  final ValueChanged<StageSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final zone = this.zone;
    if (zone == null) {
      return Center(child: Text(i18n.t('stages.empty'), style: RdText.muted));
    }
    final stages = zone.stagesOf(difficulty);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      zone.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: RdColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.t('stages.zoneStages', {'count': stages.length}),
                    style: RdText.muted,
                  ),
                ],
              ),
            ),
            _DifficultySwitch(
              i18n: i18n,
              zone: zone,
              difficulty: difficulty,
              onChanged: onDifficulty,
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdAutoGrid(
          minTileWidth: 220,
          gap: 12,
          children: [
            for (final stage in stages)
              _StageTile(i18n: i18n, stage: stage, onOpen: onOpen),
          ],
        ),
      ],
    );
  }
}

class _CompactZoneBody extends StatelessWidget {
  const _CompactZoneBody({
    required this.i18n,
    required this.zones,
    required this.zone,
    required this.difficulty,
    required this.onZone,
    required this.onDifficulty,
    required this.onOpen,
  });

  final NexusI18n i18n;
  final List<StageZone> zones;
  final StageZone? zone;
  final StageDifficulty difficulty;
  final ValueChanged<StageZone> onZone;
  final ValueChanged<StageDifficulty> onDifficulty;
  final ValueChanged<StageSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final zone = this.zone;
    if (zone == null) {
      return Center(child: Text(i18n.t('stages.empty'), style: RdText.muted));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        RdSelect<String>(
          label: i18n.t('stages.zones'),
          value: zone.zoneId,
          height: 48,
          fontSize: 14,
          options: [
            for (final option in zones)
              RdSelectOption(option.zoneId, option.name),
          ],
          onChanged: (id) =>
              onZone(zones.firstWhere((option) => option.zoneId == id)),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _DifficultySwitch(
            i18n: i18n,
            zone: zone,
            difficulty: difficulty,
            onChanged: onDifficulty,
          ),
        ),
        const SizedBox(height: 6),
        for (final stage in zone.stagesOf(difficulty))
          _StageRow(i18n: i18n, stage: stage, showZone: false, onOpen: onOpen),
      ],
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({
    required this.i18n,
    required this.stages,
    required this.compact,
    required this.showZone,
    required this.onOpen,
  });

  final NexusI18n i18n;
  final List<StageSummary> stages;
  final bool compact;
  final bool showZone;
  final ValueChanged<StageSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return Center(child: Text(i18n.t('stages.empty'), style: RdText.muted));
    }
    return ListView.builder(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 8, 16, 24)
          : const EdgeInsets.fromLTRB(32, 16, 32, 32),
      itemCount: stages.length,
      itemBuilder: (context, index) => _StageRow(
        i18n: i18n,
        stage: stages[index],
        showZone: showZone,
        onOpen: onOpen,
      ),
    );
  }
}

List<Widget> _stageChips(NexusI18n i18n, StageSummary stage) {
  return [
    if (stage.levelId == null)
      RdPill(label: i18n.t('stages.story'), textColor: RdColors.muted)
    else
      RdPill(label: i18n.t('stages.ap', {'ap': stage.apCost})),
    if (stage.bossMark)
      RdPill(
        label: i18n.t('stages.boss'),
        color: RdColors.dangerFill,
        textColor: RdColors.dangerText,
      ),
  ];
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.i18n,
    required this.stage,
    required this.onOpen,
  });

  final NexusI18n i18n;
  final StageSummary stage;
  final ValueChanged<StageSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: i18n.t('stages.openStage', {
        'code': stage.code,
        'name': stage.name,
      }),
      excludeSemantics: true,
      child: Material(
        color: RdColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.tile),
          side: const BorderSide(color: RdColors.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.tile),
          onTap: () => onOpen(stage),
          child: Opacity(
            opacity: stage.levelId == null ? 0.72 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        stage.code,
                        style: RdText.mono(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stage.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RdText.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _stageChips(i18n, stage),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.i18n,
    required this.stage,
    required this.showZone,
    required this.onOpen,
  });

  final NexusI18n i18n;
  final StageSummary stage;
  final bool showZone;
  final ValueChanged<StageSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: i18n.t('stages.openStage', {
        'code': stage.code,
        'name': stage.name,
      }),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onOpen(stage),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: RdColors.hairline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  stage.code,
                  style: RdText.mono(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: stage.levelId == null
                            ? RdColors.secondary
                            : RdColors.text,
                      ),
                    ),
                    if (showZone && stage.zoneName != null)
                      Text(
                        stage.zoneName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RdText.small,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ..._stageChips(i18n, stage)
                  .expand((chip) => [chip, const SizedBox(width: 6)]),
            ],
          ),
        ),
      ),
    );
  }
}
