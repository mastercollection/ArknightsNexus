import 'dart:math' as math;

import '../../domain/stage.dart';
import '../../raw_models/enemy_database.dart';
import '../../raw_models/enemy_handbook.dart';
import '../../raw_models/level_data.dart';
import '../../raw_models/stage_table.dart';
import '../../raw_models/zone_table.dart';
import 'stage_path_finder.dart';

class StageNormalizer {
  const StageNormalizer();

  /// Every stage of [stageTable] with an id and a code.
  List<StageSummary> summaries(
    RawStageTable stageTable,
    RawZoneTable zoneTable,
  ) {
    final result = <StageSummary>[];
    for (final raw in stageTable.stages.values) {
      final stageId = raw.stageId.trim();
      final code = (raw.code ?? '').trim();
      if (stageId.isEmpty || code.isEmpty) {
        continue;
      }
      final zone = zoneTable.zones[raw.zoneId];
      result.add(
        StageSummary(
          stageId: stageId,
          code: code,
          name: (raw.name ?? '').trim(),
          zoneId: raw.zoneId,
          zoneName: zone == null ? null : _zoneName(zone),
          zoneType: zone?.type,
          stageType: raw.stageType,
          difficulty: raw.difficulty,
          diffGroup: raw.diffGroup,
          levelId: raw.levelId,
          apCost: raw.apCost,
          dangerLevel: raw.dangerLevel,
          bossMark: raw.bossMark,
          description: raw.description,
          rewards: [
            for (final reward in raw.displayDetailRewards)
              StageReward(
                type: reward.type,
                id: reward.id,
                dropType: reward.dropType,
                occPercent: reward.occPercent,
              ),
          ],
        ),
      );
    }
    return result;
  }

  /// Every enemy of [database], with its stats at each of its levels and
  /// what the archive ([handbook]) says of it.
  List<EnemyEntry> enemies(
    RawEnemyDatabase database,
    RawEnemyHandbookTable handbook,
  ) {
    final result = <EnemyEntry>[];
    for (final MapEntry(key: id, value: levels) in database.enemies.entries) {
      final base = database.resolve(id, 0);
      if (base == null) {
        continue;
      }
      final archive = handbook.enemyData[id];
      result.add(
        EnemyEntry(
          enemyId: id,
          name: archive?.name ?? base.name.value ?? id,
          enemyIndex: archive?.enemyIndex,
          levelType: archive?.enemyLevel ?? base.levelType.value ?? 'NORMAL',
          description: archive?.description ?? base.description.value,
          damageType: archive?.damageType ?? const [],
          abilities: [
            for (final ability
                in archive?.abilityList ?? const <RawEnemyAbility>[])
              ability.text,
          ],
          levels: {
            for (final level in levels)
              level.level: _stats(database.resolve(id, level.level)!),
          },
        ),
      );
    }
    return result;
  }

  /// The battle of [stageId], whose level file is [level], with the enemies
  /// of [enemies] (by id). Enemies missing from it are left out unless the
  /// level defines them itself.
  StageDetail detail(
    String stageId,
    RawLevelData level,
    Map<String, EnemyEntry> enemies,
  ) {
    final map = _map(level.mapData);
    final finder = StagePathFinder(map);
    final counts = <String, int>{};
    var hasVariableSpawns = false;

    final lanes = <_LaneBuilder>[];
    final laneIndexes = <String, int>{};
    final paths = <StagePath>[];
    final pathIndexes = <String, int>{};
    final spawns = <StageSpawn>[];

    int? pathOf(RawWaveAction action) {
      final routeIndex = action.routeIndex;
      if (routeIndex < 0 || routeIndex >= level.routes.length) {
        return null;
      }
      final route = level.routes[routeIndex];
      if (route.motionMode != 'WALK' && route.motionMode != 'FLY') {
        return null;
      }
      final pathKey = _routeKey(route);
      var index = pathIndexes[pathKey];
      if (index == null) {
        final start = _position(route.startPosition);
        final end = _position(route.endPosition);
        final laneKey = '${route.motionMode} ${start.row},${start.col} '
            '${end.row},${end.col}';
        final laneIndex = laneIndexes.putIfAbsent(laneKey, () {
          lanes.add(
            _LaneBuilder(
              motionMode: route.motionMode,
              start: start,
              end: end,
              fromGate: _isInside(map, start) &&
                  map.tileAt(start).tileKey.contains('start'),
            ),
          );
          return lanes.length - 1;
        });
        index = paths.length;
        pathIndexes[pathKey] = index;
        paths.add(
          StagePath(
            laneIndex: laneIndex,
            motionMode: route.motionMode,
            steps: finder.steps(route),
          ),
        );
        lanes[laneIndex].pathIndexes.add(index);
      }
      if (action.autoPreviewRoute && !paths[index].previewed) {
        final path = paths[index];
        paths[index] = StagePath(
          laneIndex: path.laneIndex,
          motionMode: path.motionMode,
          steps: path.steps,
          previewed: true,
        );
      }
      return index;
    }

    // A wave starts once the one before has spawned everything (and its
    // post delay passed); the game often waits for the field to be cleared
    // too, which a schedule cannot know. Within a wave each fragment starts
    // its pre delay after the previous fragment's last spawn. This matches
    // the times PRTS.Map lists.
    var waveStart = 0.0;
    for (final wave in level.waves) {
      var time = waveStart + wave.preDelay;
      for (final fragment in wave.fragments) {
        time += fragment.preDelay;
        var fragmentEnd = time;
        for (final action in fragment.actions) {
          if (!action.isSpawn) {
            continue;
          }
          final variable =
              action.hiddenGroup != null || action.randomSpawnGroupKey != null;
          hasVariableSpawns |= variable;
          counts[action.key] = (counts[action.key] ?? 0) + action.count;
          final start = time + action.preDelay;
          final last = start + action.interval * math.max(action.count - 1, 0);
          fragmentEnd = math.max(fragmentEnd, last);
          final pathIndex = pathOf(action);
          if (pathIndex == null) {
            continue;
          }
          lanes[paths[pathIndex].laneIndex].enemyCount += action.count;
          spawns.add(
            StageSpawn(
              time: start,
              enemyId: action.key,
              count: action.count,
              interval: action.interval,
              pathIndex: pathIndex,
              variable: variable,
            ),
          );
        }
        time = fragmentEnd;
      }
      waveStart = time + wave.postDelay;
    }
    spawns.sort((a, b) => a.time.compareTo(b.time));

    final stageEnemies = <StageEnemy>[];
    final seen = <String>{};
    for (final ref in level.enemyDbRefs) {
      if (!seen.add(ref.id)) {
        continue;
      }
      final enemy = _stageEnemy(ref, enemies[ref.id], counts[ref.id] ?? 0);
      if (enemy != null) {
        stageEnemies.add(enemy);
      }
    }

    return StageDetail(
      stageId: stageId,
      options: StageOptions(
        characterLimit: level.options.characterLimit,
        maxLifePoint: level.options.maxLifePoint,
        initialCost: level.options.initialCost,
        maxCost: level.options.maxCost,
        costIncreaseTime: level.options.costIncreaseTime,
        moveMultiplier: level.options.moveMultiplier,
      ),
      map: map,
      lanes: [for (final lane in lanes) lane.build()],
      paths: paths,
      spawns: spawns,
      enemies: stageEnemies,
      devices: [
        for (final token in level.tokenInsts)
          StageDevice(
            characterKey: token.characterKey,
            position: _position(token.position),
          ),
      ],
      hasVariableSpawns: hasVariableSpawns,
    );
  }

  /// Identifies routes that move an enemy the same way.
  String _routeKey(RawLevelRoute route) {
    String at(RawGridPosition position) => '${position.row},${position.col}';
    return [
      route.motionMode,
      at(route.startPosition),
      at(route.endPosition),
      route.allowDiagonalMove,
      route.visitEveryCheckPoint,
      for (final checkpoint in route.checkpoints)
        '${checkpoint.type}@${at(checkpoint.position)}/${checkpoint.time}',
    ].join(' ');
  }

  bool _isInside(StageMap map, GridPosition position) =>
      position.row >= 0 &&
      position.row < map.height &&
      position.col >= 0 &&
      position.col < map.width;

  String _zoneName(RawZoneEntry zone) {
    return [zone.zoneNameFirst, zone.zoneNameSecond]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  /// The enemy as this stage has it: its level's stats with the stage's own
  /// changes on top. Null when neither [entry] nor the level defines it.
  StageEnemy? _stageEnemy(RawEnemyDbRef ref, EnemyEntry? entry, int count) {
    final overwritten = ref.overwrittenData;
    final base = ref.useDb ? entry : null;
    final baseStats = base?.levels[ref.level] ?? base?.levels[0];
    final EnemyStats stats;
    if (baseStats != null) {
      stats = overwritten == null ? baseStats : _patch(baseStats, overwritten);
    } else if (overwritten != null) {
      stats = _stats(overwritten);
    } else {
      return null;
    }
    final renamed = overwritten != null && overwritten.name.defined
        ? overwritten.name.value
        : null;
    return StageEnemy(
      enemyId: ref.id,
      name: renamed ?? entry?.name ?? ref.id,
      enemyIndex: entry?.enemyIndex,
      levelType: entry?.levelType ?? 'NORMAL',
      count: count,
      stats: stats,
      damageType: entry?.damageType ?? const [],
      abilities: entry?.abilities ?? const [],
      description: entry?.description,
    );
  }

  /// Every field of [data], defined or not: a level 0 entry leaves fields
  /// at their (meaningful) defaults without defining them.
  EnemyStats _stats(RawEnemyData data) {
    final attributes = data.attributes;
    return EnemyStats(
      maxHp: attributes.maxHp.value,
      atk: attributes.atk.value,
      def: attributes.def.value,
      magicResistance: attributes.magicResistance.value,
      moveSpeed: attributes.moveSpeed.value,
      attackSpeed: attributes.attackSpeed.value,
      baseAttackTime: attributes.baseAttackTime.value,
      // Almost no enemy defines it: undefined means the game's default.
      blockCnt: attributes.blockCnt.defined ? attributes.blockCnt.value : 1,
      massLevel: attributes.massLevel.value,
      rangeRadius: data.rangeRadius.value,
      lifePointReduce: data.lifePointReduce.value,
      hpRecoveryPerSec: attributes.hpRecoveryPerSec.value,
      applyWay: data.applyWay.value ?? 'NONE',
      motion: data.motion.value ?? 'WALK',
      immunities: [
        for (final entry in attributes.immunities.entries)
          if (entry.value.value) entry.key,
      ],
    );
  }

  /// [base] with the fields [patch] defines replaced.
  EnemyStats _patch(EnemyStats base, RawEnemyData patch) {
    T pick<T>(RawDefined<T> field, T current) =>
        field.defined ? field.value : current;
    final attributes = patch.attributes;
    final immunities = [...base.immunities];
    for (final MapEntry(key: name, value: field)
        in attributes.immunities.entries) {
      if (!field.defined) {
        continue;
      }
      immunities.remove(name);
      if (field.value) {
        immunities.add(name);
      }
    }
    return EnemyStats(
      maxHp: pick(attributes.maxHp, base.maxHp),
      atk: pick(attributes.atk, base.atk),
      def: pick(attributes.def, base.def),
      magicResistance: pick(attributes.magicResistance, base.magicResistance),
      moveSpeed: pick(attributes.moveSpeed, base.moveSpeed),
      attackSpeed: pick(attributes.attackSpeed, base.attackSpeed),
      baseAttackTime: pick(attributes.baseAttackTime, base.baseAttackTime),
      blockCnt: pick(attributes.blockCnt, base.blockCnt),
      massLevel: pick(attributes.massLevel, base.massLevel),
      rangeRadius: pick(patch.rangeRadius, base.rangeRadius),
      lifePointReduce: pick(patch.lifePointReduce, base.lifePointReduce),
      hpRecoveryPerSec:
          pick(attributes.hpRecoveryPerSec, base.hpRecoveryPerSec),
      applyWay: pick<String?>(patch.applyWay, base.applyWay) ?? base.applyWay,
      motion: pick<String?>(patch.motion, base.motion) ?? base.motion,
      immunities: immunities,
    );
  }

  /// Flips the upstream top-row-first grid to bottom-row-first.
  StageMap _map(RawMapData mapData) {
    final rows = mapData.map;
    final height = rows.length;
    final width = height == 0 ? 0 : rows.first.length;
    return StageMap(
      width: width,
      height: height,
      tiles: [
        for (var row = 0; row < height; row++)
          for (final index in rows[height - 1 - row])
            _tile(mapData.tiles[index]),
      ],
    );
  }

  StageTile _tile(RawTile raw) {
    return StageTile(
      tileKey: raw.tileKey,
      heightType: raw.heightType,
      buildableType: raw.buildableType,
      passableMask: raw.passableMask,
    );
  }

  GridPosition _position(RawGridPosition raw) {
    return GridPosition(row: raw.row, col: raw.col);
  }
}

class _LaneBuilder {
  _LaneBuilder({
    required this.motionMode,
    required this.start,
    required this.end,
    required this.fromGate,
  });

  final String motionMode;
  final GridPosition start;
  final GridPosition end;
  final bool fromGate;
  final pathIndexes = <int>[];
  var enemyCount = 0;

  StageLane build() {
    return StageLane(
      motionMode: motionMode,
      start: start,
      end: end,
      fromGate: fromGate,
      pathIndexes: pathIndexes,
      enemyCount: enemyCount,
    );
  }
}
