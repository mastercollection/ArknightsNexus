import '../../domain/stage.dart';
import '../../i18n/nexus_i18n.dart';

/// The stage list's top-level groups, from the zone type.
enum StageCategory {
  main('stages.category.main'),
  event('stages.category.event'),
  other('stages.category.other');

  const StageCategory(this.labelKey);

  final String labelKey;

  static StageCategory of(StageSummary stage) {
    switch (stage.zoneType) {
      case 'MAINLINE' || 'MAINLINE_ACTIVITY' || 'MAINLINE_RETRO':
        return main;
      case 'ACTIVITY' || 'SIDESTORY' || 'BRANCHLINE':
        return event;
      case null:
        return stage.stageType == 'MAIN' || stage.stageType == 'SUB'
            ? main
            : stage.stageType == 'ACTIVITY'
                ? event
                : other;
      default:
        return other;
    }
  }
}

/// The variants of one operation the list switches between.
enum StageDifficulty {
  normal('stages.difficulty.normal'),
  tough('stages.difficulty.tough'),
  challenge('stages.difficulty.challenge');

  const StageDifficulty(this.labelKey);

  final String labelKey;

  /// Null for stages the list leaves out: Story Mode (`EASY`, which the
  /// upstream repository has no levels for) and the six-star mode.
  static StageDifficulty? of(StageSummary stage) {
    if (stage.diffGroup == 'EASY' || stage.difficulty == 'SIX_STAR') {
      return null;
    }
    if (stage.isChallengeMode) {
      return challenge;
    }
    return stage.diffGroup == 'TOUGH' ? tough : normal;
  }
}

/// The stages of one zone, in stage table order.
class StageZone {
  const StageZone({
    required this.zoneId,
    required this.name,
    required this.category,
    required this.stages,
  });

  final String zoneId;
  final String name;
  final StageCategory category;
  final List<StageSummary> stages;

  Set<StageDifficulty> get difficulties => {
        for (final stage in stages) StageDifficulty.of(stage)!,
      };

  List<StageSummary> stagesOf(StageDifficulty difficulty) => [
        for (final stage in stages)
          if (StageDifficulty.of(stage) == difficulty) stage,
      ];
}

/// [stages] grouped by zone: main story zones by episode, events newest
/// first, the rest in table order.
List<StageZone> stageZones(List<StageSummary> stages) {
  final byZone = <String, List<StageSummary>>{};
  for (final stage in stages) {
    if (StageDifficulty.of(stage) == null) {
      continue;
    }
    (byZone[stage.zoneId] ??= []).add(stage);
  }
  final zones = [
    for (final MapEntry(key: zoneId, value: zoneStages) in byZone.entries)
      StageZone(
        zoneId: zoneId,
        name: zoneStages.first.zoneName ?? zoneId,
        category: StageCategory.of(zoneStages.first),
        stages: zoneStages,
      ),
  ];
  final main = [
    for (final zone in zones)
      if (zone.category == StageCategory.main) zone,
  ]..sort((a, b) => _episode(a.zoneId).compareTo(_episode(b.zoneId)));
  return [
    ...main,
    for (final zone in zones.reversed)
      if (zone.category == StageCategory.event) zone,
    for (final zone in zones)
      if (zone.category == StageCategory.other) zone,
  ];
}

final _episodePattern = RegExp(r'_(\d+)$');

/// `main_14` → 14; zones without a number after the numbered ones.
int _episode(String zoneId) {
  final match = _episodePattern.firstMatch(zoneId);
  return match == null ? 1 << 20 : int.parse(match.group(1)!);
}

/// The same operation at its other difficulties (same zone and code).
List<StageSummary> stageVariants(
  StageSummary stage,
  List<StageSummary> stages,
) {
  final variants = [
    for (final other in stages)
      if (other.zoneId == stage.zoneId &&
          other.code == stage.code &&
          StageDifficulty.of(other) != null)
        other,
  ]..sort(
      (a, b) =>
          StageDifficulty.of(a)!.index.compareTo(StageDifficulty.of(b)!.index),
    );
  return variants;
}

/// `m:ss`.
String formatStageTime(double seconds) {
  final whole = seconds.floor().clamp(0, 1 << 30);
  final minutes = whole ~/ 60;
  final rest = whole % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

/// Lanes numbered top to bottom, then left to right by where they start,
/// the way a player reads the map.
List<int> laneOrder(List<StageLane> lanes) {
  return [for (var i = 0; i < lanes.length; i++) i]..sort((a, b) {
      final la = lanes[a].start;
      final lb = lanes[b].start;
      if (la.row != lb.row) {
        return lb.row.compareTo(la.row);
      }
      if (la.col != lb.col) {
        return la.col.compareTo(lb.col);
      }
      return a.compareTo(b);
    });
}

String laneLabel(NexusI18n i18n, StageLane lane, int number) {
  final parts = [
    i18n.t('stages.lane', {'n': number}),
  ];
  if (lane.motionMode == 'FLY') {
    parts.add(i18n.t('stages.lane.fly'));
  }
  if (!lane.fromGate) {
    parts.add(i18n.t('stages.lane.midMap'));
  }
  return parts.join(' · ');
}

final _markupPattern = RegExp(r'<@[^>]*>|</>|<\$[^>]*>');

/// A stage briefing without the game's `<@...>` style markup.
String plainStageText(String text) => text.replaceAll(_markupPattern, '');
