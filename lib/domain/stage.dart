/// A stage as the stage list shows it, from `stage_table` and `zone_table`.
class StageSummary {
  const StageSummary({
    required this.stageId,
    required this.code,
    required this.name,
    required this.zoneId,
    this.zoneName,
    this.zoneType,
    required this.stageType,
    required this.difficulty,
    required this.diffGroup,
    this.levelId,
    required this.apCost,
    this.dangerLevel,
    this.bossMark = false,
    this.description,
    this.rewards = const [],
  });

  final String stageId;
  final String code;
  final String name;
  final String zoneId;

  /// Such as `Episode 1 Evil Time Part 2`; null when the zone is unknown.
  final String? zoneName;

  /// `MAINLINE`, `ACTIVITY`, `SIDESTORY`, `WEEKLY`, `CAMPAIGN`, ...; null
  /// when the zone is unknown.
  final String? zoneType;
  final String stageType;
  final String difficulty;
  final String diffGroup;

  /// Null for stages without a battle (story-only stages); they have no
  /// [StageDetail].
  final String? levelId;
  final int apCost;
  final String? dangerLevel;
  final bool bossMark;

  /// The briefing, with the game's `<@...>` markup.
  final String? description;
  final List<StageReward> rewards;

  /// Whether this is a Challenge Mode stage, which shares the level of its
  /// normal stage.
  bool get isChallengeMode => difficulty == 'FOUR_STAR';

  factory StageSummary.fromJson(Map<String, Object?> json) {
    return StageSummary(
      stageId: json['stageId'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      zoneId: json['zoneId'] as String,
      zoneName: json['zoneName'] as String?,
      zoneType: json['zoneType'] as String?,
      stageType: json['stageType'] as String,
      difficulty: json['difficulty'] as String,
      diffGroup: json['diffGroup'] as String,
      levelId: json['levelId'] as String?,
      apCost: (json['apCost'] as num).toInt(),
      dangerLevel: json['dangerLevel'] as String?,
      bossMark: json['bossMark'] as bool? ?? false,
      description: json['description'] as String?,
      rewards: _list(
        json['rewards'],
        (value) => StageReward.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'stageId': stageId,
      'code': code,
      'name': name,
      'zoneId': zoneId,
      if (zoneName != null) 'zoneName': zoneName,
      if (zoneType != null) 'zoneType': zoneType,
      'stageType': stageType,
      'difficulty': difficulty,
      'diffGroup': diffGroup,
      if (levelId != null) 'levelId': levelId,
      'apCost': apCost,
      if (dangerLevel != null) 'dangerLevel': dangerLevel,
      if (bossMark) 'bossMark': bossMark,
      if (description != null) 'description': description,
      if (rewards.isNotEmpty)
        'rewards': rewards.map((entry) => entry.toJson()).toList(),
    };
  }
}

/// A reward the stage screen of the game lists.
class StageReward {
  const StageReward({
    required this.type,
    required this.id,
    required this.dropType,
    required this.occPercent,
  });

  /// `MATERIAL`, `CHAR`, `CARD_EXP`, `DIAMOND`, `FURN`, ...
  final String type;
  final String id;

  /// `ONCE`, `NORMAL`, `ADDITIONAL`, `COMPLETE`, `SPECIAL`, ...
  final String dropType;

  /// `ALWAYS`, `ALMOST`, `USUAL`, `OFTEN` or `SOMETIMES`.
  final String occPercent;

  factory StageReward.fromJson(Map<String, Object?> json) {
    return StageReward(
      type: json['type'] as String,
      id: json['id'] as String,
      dropType: json['dropType'] as String,
      occPercent: json['occPercent'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'id': id,
      'dropType': dropType,
      'occPercent': occPercent,
    };
  }
}

/// A stage's battle: its map, the enemies' paths and spawn schedule, from
/// its level file and the enemy tables.
class StageDetail {
  const StageDetail({
    required this.stageId,
    required this.options,
    required this.map,
    this.lanes = const [],
    this.paths = const [],
    this.spawns = const [],
    this.enemies = const [],
    this.devices = const [],
    this.hasVariableSpawns = false,
  });

  final String stageId;
  final StageOptions options;
  final StageMap map;

  /// Where enemies come from and go to, one per start, end and motion.
  final List<StageLane> lanes;

  /// Every distinct path the spawns take ([StageSpawn.pathIndex]).
  final List<StagePath> paths;

  /// Enemy spawns in time order.
  final List<StageSpawn> spawns;

  /// In the order the level lists them.
  final List<StageEnemy> enemies;

  /// Devices placed on the map before the battle.
  final List<StageDevice> devices;

  /// Whether some spawns are random or only happen in some variant of the
  /// level, so [StageEnemy.count] and the schedule are not exact.
  final bool hasVariableSpawns;

  /// Seconds until the last spawn.
  double get lastSpawnTime => spawns.isEmpty
      ? 0
      : spawns
          .map((spawn) => spawn.time + spawn.interval * (spawn.count - 1))
          .reduce((a, b) => a > b ? a : b);

  factory StageDetail.fromJson(Map<String, Object?> json) {
    return StageDetail(
      stageId: json['stageId'] as String,
      options: StageOptions.fromJson(_map(json['options'])),
      map: StageMap.fromJson(_map(json['map'])),
      lanes: _list(json['lanes'], (value) => StageLane.fromJson(_map(value))),
      paths: _list(json['paths'], (value) => StagePath.fromJson(_map(value))),
      spawns:
          _list(json['spawns'], (value) => StageSpawn.fromJson(_map(value))),
      enemies:
          _list(json['enemies'], (value) => StageEnemy.fromJson(_map(value))),
      devices:
          _list(json['devices'], (value) => StageDevice.fromJson(_map(value))),
      hasVariableSpawns: json['hasVariableSpawns'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'stageId': stageId,
      'options': options.toJson(),
      'map': map.toJson(),
      'lanes': lanes.map((entry) => entry.toJson()).toList(),
      'paths': paths.map((entry) => entry.toJson()).toList(),
      'spawns': spawns.map((entry) => entry.toJson()).toList(),
      'enemies': enemies.map((entry) => entry.toJson()).toList(),
      'devices': devices.map((entry) => entry.toJson()).toList(),
      if (hasVariableSpawns) 'hasVariableSpawns': hasVariableSpawns,
    };
  }
}

class StageOptions {
  const StageOptions({
    required this.characterLimit,
    required this.maxLifePoint,
    required this.initialCost,
    required this.maxCost,
    required this.costIncreaseTime,
    this.moveMultiplier = 1,
  });

  final int characterLimit;
  final int maxLifePoint;
  final int initialCost;
  final int maxCost;

  /// Seconds per DP.
  final double costIncreaseTime;

  /// The level's move speed multiplier (0.5 in every level). Playback
  /// takes an enemy to walk `moveSpeed × moveMultiplier` tiles a second,
  /// an estimate: the game's own rule is not in the data.
  final double moveMultiplier;

  factory StageOptions.fromJson(Map<String, Object?> json) {
    return StageOptions(
      characterLimit: (json['characterLimit'] as num).toInt(),
      maxLifePoint: (json['maxLifePoint'] as num).toInt(),
      initialCost: (json['initialCost'] as num).toInt(),
      maxCost: (json['maxCost'] as num).toInt(),
      costIncreaseTime: (json['costIncreaseTime'] as num).toDouble(),
      moveMultiplier: (json['moveMultiplier'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterLimit': characterLimit,
      'maxLifePoint': maxLifePoint,
      'initialCost': initialCost,
      'maxCost': maxCost,
      'costIncreaseTime': costIncreaseTime,
      'moveMultiplier': moveMultiplier,
    };
  }
}

class StageMap {
  const StageMap({
    required this.width,
    required this.height,
    this.tiles = const [],
  });

  final int width;
  final int height;

  /// [width] × [height] tiles, bottom row first, each row left to right:
  /// the game's own row order, so a [GridPosition] indexes it directly.
  final List<StageTile> tiles;

  StageTile tileAt(GridPosition position) =>
      tiles[position.row * width + position.col];

  factory StageMap.fromJson(Map<String, Object?> json) {
    return StageMap(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      tiles: _list(json['tiles'], (value) => StageTile.fromJson(_map(value))),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'width': width,
      'height': height,
      'tiles': tiles.map((entry) => entry.toJson()).toList(),
    };
  }
}

class StageTile {
  const StageTile({
    required this.tileKey,
    required this.heightType,
    required this.buildableType,
    required this.passableMask,
  });

  final String tileKey;
  final String heightType;
  final String buildableType;
  final String passableMask;

  bool get isHighland => heightType == 'HIGHLAND';

  factory StageTile.fromJson(Map<String, Object?> json) {
    return StageTile(
      tileKey: json['tileKey'] as String,
      heightType: json['heightType'] as String,
      buildableType: json['buildableType'] as String,
      passableMask: json['passableMask'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'tileKey': tileKey,
      'heightType': heightType,
      'buildableType': buildableType,
      'passableMask': passableMask,
    };
  }
}

class GridPosition {
  const GridPosition({required this.row, required this.col});

  /// Counted from the bottom row.
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  factory GridPosition.fromJson(Map<String, Object?> json) {
    return GridPosition(
      row: (json['row'] as num).toInt(),
      col: (json['col'] as num).toInt(),
    );
  }

  Map<String, Object?> toJson() => {'row': row, 'col': col};
}

/// Enemies going from one start to one end the same way of moving: the
/// unit the route filter offers.
class StageLane {
  const StageLane({
    required this.motionMode,
    required this.start,
    required this.end,
    required this.fromGate,
    this.pathIndexes = const [],
    this.enemyCount = 0,
  });

  /// `WALK` or `FLY`.
  final String motionMode;
  final GridPosition start;
  final GridPosition end;

  /// Whether [start] is a spawn gate tile; false for enemies that appear in
  /// the middle of the map.
  final bool fromGate;

  /// The [StageDetail.paths] of this lane: its variants.
  final List<int> pathIndexes;

  /// Enemies that spawn on this lane.
  final int enemyCount;

  factory StageLane.fromJson(Map<String, Object?> json) {
    return StageLane(
      motionMode: json['motionMode'] as String,
      start: GridPosition.fromJson(_map(json['start'])),
      end: GridPosition.fromJson(_map(json['end'])),
      fromGate: json['fromGate'] as bool? ?? true,
      pathIndexes:
          _list(json['pathIndexes'], (value) => (value! as num).toInt()),
      enemyCount: (json['enemyCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'motionMode': motionMode,
      'start': start.toJson(),
      'end': end.toJson(),
      'fromGate': fromGate,
      'pathIndexes': pathIndexes,
      'enemyCount': enemyCount,
    };
  }
}

/// The way one or more spawns move: tile by tile for walking enemies (the
/// shortest way between the level's checkpoints, as PRTS.Map draws it),
/// checkpoint to checkpoint for flying ones.
class StagePath {
  const StagePath({
    required this.laneIndex,
    required this.motionMode,
    this.steps = const [],
    this.previewed = false,
  });

  final int laneIndex;
  final String motionMode;

  /// Where the enemy passes, in order; the first is where it spawns.
  final List<PathStep> steps;

  /// Whether the game previews this path before some spawn on it.
  final bool previewed;

  factory StagePath.fromJson(Map<String, Object?> json) {
    return StagePath(
      laneIndex: (json['laneIndex'] as num).toInt(),
      motionMode: json['motionMode'] as String,
      steps: _list(json['steps'], (value) => PathStep.fromJson(_map(value))),
      previewed: json['previewed'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'laneIndex': laneIndex,
      'motionMode': motionMode,
      'steps': steps.map((entry) => entry.toJson()).toList(),
      if (previewed) 'previewed': previewed,
    };
  }
}

class PathStep {
  const PathStep({
    required this.position,
    this.wait = 0,
    this.jump = false,
    this.waitsForSchedule = false,
  });

  final GridPosition position;

  /// Seconds the enemy stays here.
  final double wait;

  /// Whether the enemy reaches this step without passing between: it
  /// disappears at the step before and appears here (tunnels, teleports).
  final bool jump;

  /// Whether it also waits here until a point of the wave's schedule, which
  /// [wait] does not count.
  final bool waitsForSchedule;

  factory PathStep.fromJson(Map<String, Object?> json) {
    return PathStep(
      position: GridPosition.fromJson(_map(json['position'])),
      wait: (json['wait'] as num?)?.toDouble() ?? 0,
      jump: json['jump'] as bool? ?? false,
      waitsForSchedule: json['waitsForSchedule'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'position': position.toJson(),
      if (wait != 0) 'wait': wait,
      if (jump) 'jump': jump,
      if (waitsForSchedule) 'waitsForSchedule': waitsForSchedule,
    };
  }
}

/// One spawn action: [count] of [enemyId], [interval] seconds apart.
class StageSpawn {
  const StageSpawn({
    required this.time,
    required this.enemyId,
    required this.count,
    required this.interval,
    required this.pathIndex,
    this.variable = false,
  });

  /// Seconds from the battle's start to the first enemy.
  final double time;
  final String enemyId;
  final int count;
  final double interval;
  final int pathIndex;

  /// Whether it is random or only happens in some variant of the level.
  final bool variable;

  factory StageSpawn.fromJson(Map<String, Object?> json) {
    return StageSpawn(
      time: (json['time'] as num).toDouble(),
      enemyId: json['enemyId'] as String,
      count: (json['count'] as num).toInt(),
      interval: (json['interval'] as num).toDouble(),
      pathIndex: (json['pathIndex'] as num).toInt(),
      variable: json['variable'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'time': time,
      'enemyId': enemyId,
      'count': count,
      'interval': interval,
      'pathIndex': pathIndex,
      if (variable) 'variable': variable,
    };
  }
}

class StageDevice {
  const StageDevice({required this.characterKey, required this.position});

  final String characterKey;
  final GridPosition position;

  factory StageDevice.fromJson(Map<String, Object?> json) {
    return StageDevice(
      characterKey: json['characterKey'] as String,
      position: GridPosition.fromJson(_map(json['position'])),
    );
  }

  Map<String, Object?> toJson() {
    return {'characterKey': characterKey, 'position': position.toJson()};
  }
}

/// An enemy of the region's enemy list, with its stats at each level a
/// stage can use.
class EnemyEntry {
  const EnemyEntry({
    required this.enemyId,
    required this.name,
    this.enemyIndex,
    required this.levelType,
    this.description,
    this.damageType = const [],
    this.abilities = const [],
    this.levels = const {},
  });

  final String enemyId;
  final String name;

  /// The archive index such as `B2`; null for enemies the archive does not
  /// list.
  final String? enemyIndex;

  /// `NORMAL`, `ELITE` or `BOSS`.
  final String levelType;
  final String? description;
  final List<String> damageType;
  final List<String> abilities;

  /// Stats per enemy level (0 is the base enemy).
  final Map<int, EnemyStats> levels;

  factory EnemyEntry.fromJson(Map<String, Object?> json) {
    return EnemyEntry(
      enemyId: json['enemyId'] as String,
      name: json['name'] as String,
      enemyIndex: json['enemyIndex'] as String?,
      levelType: json['levelType'] as String,
      description: json['description'] as String?,
      damageType: _list(json['damageType'], (value) => value! as String),
      abilities: _list(json['abilities'], (value) => value! as String),
      levels: _map(json['levels']).map(
        (level, stats) =>
            MapEntry(int.parse(level), EnemyStats.fromJson(_map(stats))),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enemyId': enemyId,
      'name': name,
      if (enemyIndex != null) 'enemyIndex': enemyIndex,
      'levelType': levelType,
      if (description != null) 'description': description,
      'damageType': damageType,
      'abilities': abilities,
      'levels': {
        for (final entry in levels.entries)
          '${entry.key}': entry.value.toJson(),
      },
    };
  }
}

/// An enemy of a stage, with the stats it has there.
class StageEnemy {
  const StageEnemy({
    required this.enemyId,
    required this.name,
    this.enemyIndex,
    required this.levelType,
    required this.count,
    required this.stats,
    this.damageType = const [],
    this.abilities = const [],
    this.description,
  });

  final String enemyId;
  final String name;

  /// The archive index such as `B2`; null for enemies the archive does not
  /// list.
  final String? enemyIndex;

  /// `NORMAL`, `ELITE` or `BOSS`.
  final String levelType;

  /// How many spawn over the stage.
  final int count;
  final EnemyStats stats;
  final List<String> damageType;
  final List<String> abilities;

  /// The archive's description, with the game's `<@...>` markup.
  final String? description;

  factory StageEnemy.fromJson(Map<String, Object?> json) {
    return StageEnemy(
      enemyId: json['enemyId'] as String,
      name: json['name'] as String,
      enemyIndex: json['enemyIndex'] as String?,
      levelType: json['levelType'] as String,
      count: (json['count'] as num).toInt(),
      stats: EnemyStats.fromJson(_map(json['stats'])),
      damageType: _list(json['damageType'], (value) => value! as String),
      abilities: _list(json['abilities'], (value) => value! as String),
      description: json['description'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enemyId': enemyId,
      'name': name,
      if (enemyIndex != null) 'enemyIndex': enemyIndex,
      'levelType': levelType,
      'count': count,
      'stats': stats.toJson(),
      'damageType': damageType,
      'abilities': abilities,
      if (description != null) 'description': description,
    };
  }
}

class EnemyStats {
  const EnemyStats({
    required this.maxHp,
    required this.atk,
    required this.def,
    required this.magicResistance,
    required this.moveSpeed,
    required this.attackSpeed,
    required this.baseAttackTime,
    required this.blockCnt,
    required this.massLevel,
    required this.rangeRadius,
    required this.lifePointReduce,
    required this.hpRecoveryPerSec,
    required this.applyWay,
    required this.motion,
    this.immunities = const [],
  });

  final int maxHp;
  final int atk;
  final int def;
  final double magicResistance;
  final double moveSpeed;
  final double attackSpeed;

  /// Seconds between attacks at 100 attack speed.
  final double baseAttackTime;

  /// How many blockers it takes to block.
  final int blockCnt;

  /// Weight.
  final int massLevel;

  /// Attack range in tiles; 0 or -1 for melee enemies.
  final double rangeRadius;

  /// Life points lost when it reaches a protection point.
  final int lifePointReduce;
  final double hpRecoveryPerSec;

  /// `MELEE`, `RANGED`, `ALL` or `NONE`.
  final String applyWay;

  /// `WALK` or `FLY`.
  final String motion;

  /// The effects it is immune to: `stun`, `silence`, `sleep`, `frozen`,
  /// `levitate`, ...
  final List<String> immunities;

  factory EnemyStats.fromJson(Map<String, Object?> json) {
    return EnemyStats(
      maxHp: (json['maxHp'] as num).toInt(),
      atk: (json['atk'] as num).toInt(),
      def: (json['def'] as num).toInt(),
      magicResistance: (json['magicResistance'] as num).toDouble(),
      moveSpeed: (json['moveSpeed'] as num).toDouble(),
      attackSpeed: (json['attackSpeed'] as num).toDouble(),
      baseAttackTime: (json['baseAttackTime'] as num).toDouble(),
      blockCnt: (json['blockCnt'] as num).toInt(),
      massLevel: (json['massLevel'] as num).toInt(),
      rangeRadius: (json['rangeRadius'] as num).toDouble(),
      lifePointReduce: (json['lifePointReduce'] as num).toInt(),
      hpRecoveryPerSec: (json['hpRecoveryPerSec'] as num).toDouble(),
      applyWay: json['applyWay'] as String,
      motion: json['motion'] as String,
      immunities: _list(json['immunities'], (value) => value! as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'maxHp': maxHp,
      'atk': atk,
      'def': def,
      'magicResistance': magicResistance,
      'moveSpeed': moveSpeed,
      'attackSpeed': attackSpeed,
      'baseAttackTime': baseAttackTime,
      'blockCnt': blockCnt,
      'massLevel': massLevel,
      'rangeRadius': rangeRadius,
      'lifePointReduce': lifePointReduce,
      'hpRecoveryPerSec': hpRecoveryPerSec,
      'applyWay': applyWay,
      'motion': motion,
      'immunities': immunities,
    };
  }
}

Map<String, Object?> _map(Object? value) {
  return Map<String, Object?>.from(value! as Map);
}

List<T> _list<T>(Object? value, T Function(Object?) convert) {
  return (value as List? ?? const []).map(convert).toList();
}
