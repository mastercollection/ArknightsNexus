/// A stage as the stage list shows it, from `stage_table` and `zone_table`.
class StageSummary {
  const StageSummary({
    required this.stageId,
    required this.code,
    required this.name,
    required this.zoneId,
    this.zoneName,
    required this.stageType,
    required this.difficulty,
    required this.diffGroup,
    this.levelId,
    required this.apCost,
    this.dangerLevel,
    this.bossMark = false,
  });

  final String stageId;
  final String code;
  final String name;
  final String zoneId;

  /// Such as `Episode 1 Evil Time Part 2`; null when the zone is unknown.
  final String? zoneName;
  final String stageType;
  final String difficulty;
  final String diffGroup;

  /// Null for stages without a battle (story-only stages); they have no
  /// [StageDetail].
  final String? levelId;
  final int apCost;
  final String? dangerLevel;
  final bool bossMark;

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
      stageType: json['stageType'] as String,
      difficulty: json['difficulty'] as String,
      diffGroup: json['diffGroup'] as String,
      levelId: json['levelId'] as String?,
      apCost: (json['apCost'] as num).toInt(),
      dangerLevel: json['dangerLevel'] as String?,
      bossMark: json['bossMark'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'stageId': stageId,
      'code': code,
      'name': name,
      'zoneId': zoneId,
      if (zoneName != null) 'zoneName': zoneName,
      'stageType': stageType,
      'difficulty': difficulty,
      'diffGroup': diffGroup,
      if (levelId != null) 'levelId': levelId,
      'apCost': apCost,
      if (dangerLevel != null) 'dangerLevel': dangerLevel,
      if (bossMark) 'bossMark': bossMark,
    };
  }
}

/// A stage's battle: its map, routes and enemies, from its level file and
/// the enemy tables.
class StageDetail {
  const StageDetail({
    required this.stageId,
    required this.options,
    required this.map,
    this.routes = const [],
    this.enemies = const [],
    this.devices = const [],
    this.hasVariableSpawns = false,
  });

  final String stageId;
  final StageOptions options;
  final StageMap map;

  /// Indexed as the level's routes (spawns refer to them by index), unused
  /// placeholder routes included.
  final List<StageRoute> routes;

  /// In the order the level lists them.
  final List<StageEnemy> enemies;

  /// Devices placed on the map before the battle.
  final List<StageDevice> devices;

  /// Whether some spawns are random or only happen in some variant of the
  /// level, so [StageEnemy.count] is not exact.
  final bool hasVariableSpawns;

  factory StageDetail.fromJson(Map<String, Object?> json) {
    return StageDetail(
      stageId: json['stageId'] as String,
      options: StageOptions.fromJson(_map(json['options'])),
      map: StageMap.fromJson(_map(json['map'])),
      routes:
          _list(json['routes'], (value) => StageRoute.fromJson(_map(value))),
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
      'routes': routes.map((entry) => entry.toJson()).toList(),
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
  });

  final int characterLimit;
  final int maxLifePoint;
  final int initialCost;
  final int maxCost;

  /// Seconds per DP.
  final double costIncreaseTime;

  factory StageOptions.fromJson(Map<String, Object?> json) {
    return StageOptions(
      characterLimit: (json['characterLimit'] as num).toInt(),
      maxLifePoint: (json['maxLifePoint'] as num).toInt(),
      initialCost: (json['initialCost'] as num).toInt(),
      maxCost: (json['maxCost'] as num).toInt(),
      costIncreaseTime: (json['costIncreaseTime'] as num).toDouble(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterLimit': characterLimit,
      'maxLifePoint': maxLifePoint,
      'initialCost': initialCost,
      'maxCost': maxCost,
      'costIncreaseTime': costIncreaseTime,
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

class StageRoute {
  const StageRoute({
    required this.motionMode,
    required this.start,
    required this.end,
    this.waypoints = const [],
  });

  /// `WALK`, `FLY`, or `E_NUM` for an unused placeholder route.
  final String motionMode;
  final GridPosition start;
  final GridPosition end;

  /// The route's `MOVE` checkpoints, in order.
  final List<GridPosition> waypoints;

  bool get isPlaceholder => motionMode == 'E_NUM';

  factory StageRoute.fromJson(Map<String, Object?> json) {
    return StageRoute(
      motionMode: json['motionMode'] as String,
      start: GridPosition.fromJson(_map(json['start'])),
      end: GridPosition.fromJson(_map(json['end'])),
      waypoints: _list(
        json['waypoints'],
        (value) => GridPosition.fromJson(_map(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'motionMode': motionMode,
      'start': start.toJson(),
      'end': end.toJson(),
      'waypoints': waypoints.map((entry) => entry.toJson()).toList(),
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
