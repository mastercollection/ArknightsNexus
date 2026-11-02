import 'enemy_database.dart';
import 'raw_helpers.dart';

/// A level file under `gamedata/levels`, such as
/// `levels/obt/main/level_main_01-07.json`; see [levelFilePath].
class RawLevelData {
  const RawLevelData({
    required this.options,
    required this.mapData,
    this.routes = const [],
    this.enemyDbRefs = const [],
    this.waves = const [],
    this.tokenInsts = const [],
    this.runes = const [],
  });

  final RawLevelOptions options;
  final RawMapData mapData;
  final List<RawLevelRoute> routes;
  final List<RawEnemyDbRef> enemyDbRefs;
  final List<RawLevelWave> waves;

  /// Devices placed on the map before the battle, such as the Stun Generator
  /// of 1-7.
  final List<RawTokenInst> tokenInsts;

  /// Extra rules some modes add (Challenge Mode, Adverse Environment, ...);
  /// [RawLevelRune.difficultyMask] says which.
  final List<RawLevelRune> runes;

  factory RawLevelData.fromJson(Map<String, Object?> json) {
    return RawLevelData(
      options: RawLevelOptions.fromJson(rawMap(json['options'])),
      mapData: RawMapData.fromJson(rawMap(json['mapData'])),
      routes: rawListOf(json['routes'], RawLevelRoute.fromJson),
      enemyDbRefs: rawListOf(json['enemyDbRefs'], RawEnemyDbRef.fromJson),
      waves: rawListOf(json['waves'], RawLevelWave.fromJson),
      tokenInsts: rawListOf(
        rawMap(json['predefines'])['tokenInsts'],
        RawTokenInst.fromJson,
      ),
      runes: rawListOf(json['runes'], RawLevelRune.fromJson),
    );
  }
}

/// The level file path, relative to `gamedata/levels`, of a stage's
/// `levelId`: the upstream folders are lower case while the ids are not.
String levelFilePath(String levelId) => '${levelId.toLowerCase()}.json';

class RawLevelOptions {
  const RawLevelOptions({
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

  /// 0.5 in every level.
  final double moveMultiplier;

  factory RawLevelOptions.fromJson(Map<String, Object?> json) {
    return RawLevelOptions(
      characterLimit: rawInt(json, 'characterLimit'),
      maxLifePoint: rawInt(json, 'maxLifePoint'),
      initialCost: rawInt(json, 'initialCost'),
      maxCost: rawInt(json, 'maxCost'),
      costIncreaseTime: rawDouble(json, 'costIncreaseTime'),
      moveMultiplier: rawDouble(json, 'moveMultiplier', defaultValue: 1),
    );
  }
}

class RawMapData {
  const RawMapData({this.map = const [], this.tiles = const []});

  /// Indexes into [tiles], top row first. Positions elsewhere in the level
  /// count rows from the bottom, so `row` r is `map[map.length - 1 - r]`.
  final List<List<int>> map;
  final List<RawTile> tiles;

  factory RawMapData.fromJson(Map<String, Object?> json) {
    return RawMapData(
      map: _grid(json['map']),
      tiles: rawListOf(json['tiles'], RawTile.fromJson),
    );
  }

  /// Older levels store the grid as rows of cells; newer ones as
  /// `{row_size, column_size, matrix_data}` with the same cells flattened.
  static List<List<int>> _grid(Object? value) {
    List<int> cells(Object? list) => list is List
        ? list.map((cell) => (cell as num).toInt()).toList()
        : const [];

    if (value is List) {
      return value.map(cells).toList();
    }
    if (value is Map) {
      final json = rawMap(value);
      final rows = rawInt(json, 'row_size');
      final columns = rawInt(json, 'column_size');
      final flat = cells(json['matrix_data']);
      if (columns <= 0 || flat.length != rows * columns) {
        return const [];
      }
      return [
        for (var row = 0; row < rows; row++)
          flat.sublist(row * columns, (row + 1) * columns),
      ];
    }
    return const [];
  }
}

class RawTile {
  const RawTile({
    required this.tileKey,
    required this.heightType,
    required this.buildableType,
    required this.passableMask,
  });

  /// `tile_road`, `tile_wall`, `tile_start`, `tile_end`, `tile_forbidden`,
  /// `tile_floor`, plus event tiles such as `tile_toxic`.
  final String tileKey;

  /// `LOWLAND` or `HIGHLAND`.
  final String heightType;

  /// `MELEE`, `RANGED`, `ALL` or `NONE`.
  final String buildableType;

  /// `ALL`, `WALK_ONLY`, `FLY_ONLY` or `NONE`.
  final String passableMask;

  factory RawTile.fromJson(Map<String, Object?> json) {
    return RawTile(
      tileKey: rawString(json, 'tileKey'),
      heightType: rawString(json, 'heightType'),
      buildableType: rawString(json, 'buildableType'),
      passableMask: rawString(json, 'passableMask'),
    );
  }
}

class RawGridPosition {
  const RawGridPosition({required this.row, required this.col});

  /// Counted from the bottom row.
  final int row;
  final int col;

  factory RawGridPosition.fromJson(Map<String, Object?> json) {
    return RawGridPosition(row: rawInt(json, 'row'), col: rawInt(json, 'col'));
  }
}

class RawLevelRoute {
  const RawLevelRoute({
    required this.motionMode,
    required this.startPosition,
    required this.endPosition,
    this.checkpoints = const [],
    this.allowDiagonalMove = true,
    this.visitEveryCheckPoint = false,
  });

  /// `WALK` or `FLY`; `E_NUM` marks an unused placeholder route (such as
  /// the one story actions point at).
  final String motionMode;
  final RawGridPosition startPosition;
  final RawGridPosition endPosition;
  final List<RawCheckpoint> checkpoints;
  final bool allowDiagonalMove;

  /// Lets a walking enemy pass holes (`tile_hole`) on its way.
  final bool visitEveryCheckPoint;

  factory RawLevelRoute.fromJson(Map<String, Object?> json) {
    return RawLevelRoute(
      motionMode: rawString(json, 'motionMode'),
      startPosition: RawGridPosition.fromJson(rawMap(json['startPosition'])),
      endPosition: RawGridPosition.fromJson(rawMap(json['endPosition'])),
      checkpoints: rawListOf(json['checkpoints'], RawCheckpoint.fromJson),
      allowDiagonalMove: rawBool(json, 'allowDiagonalMove', defaultValue: true),
      visitEveryCheckPoint: rawBool(json, 'visitEveryCheckPoint'),
    );
  }
}

class RawCheckpoint {
  const RawCheckpoint({
    required this.type,
    required this.position,
    required this.time,
  });

  /// `MOVE`, `PATROL_MOVE`, `WAIT_FOR_SECONDS`, `WAIT_CURRENT_FRAGMENT_TIME`,
  /// `WAIT_CURRENT_WAVE_TIME`, `DISAPPEAR`, `APPEAR_AT_POS`, ...
  final String type;
  final RawGridPosition position;

  /// Seconds, for the waits.
  final double time;

  factory RawCheckpoint.fromJson(Map<String, Object?> json) {
    return RawCheckpoint(
      type: rawString(json, 'type'),
      position: RawGridPosition.fromJson(rawMap(json['position'])),
      time: rawDouble(json, 'time'),
    );
  }
}

class RawEnemyDbRef {
  const RawEnemyDbRef({
    required this.useDb,
    required this.id,
    required this.level,
    this.overwrittenData,
  });

  /// False when [overwrittenData] is the whole enemy rather than a patch of
  /// its `enemy_database` entry.
  final bool useDb;
  final String id;

  /// Which `enemy_database` level entry of [id] this stage uses.
  final int level;

  /// This stage's changes to the enemy: only its `m_defined` fields apply.
  final RawEnemyData? overwrittenData;

  factory RawEnemyDbRef.fromJson(Map<String, Object?> json) {
    final overwritten = json['overwrittenData'];
    return RawEnemyDbRef(
      useDb: rawBool(json, 'useDb', defaultValue: true),
      id: rawString(json, 'id'),
      level: rawInt(json, 'level'),
      overwrittenData: overwritten is Map
          ? RawEnemyData.fromJson(rawMap(overwritten))
          : null,
    );
  }
}

class RawLevelWave {
  const RawLevelWave({
    required this.preDelay,
    this.postDelay = 0,
    this.fragments = const [],
  });

  final double preDelay;
  final double postDelay;
  final List<RawWaveFragment> fragments;

  factory RawLevelWave.fromJson(Map<String, Object?> json) {
    return RawLevelWave(
      preDelay: rawDouble(json, 'preDelay'),
      postDelay: rawDouble(json, 'postDelay'),
      fragments: rawListOf(json['fragments'], RawWaveFragment.fromJson),
    );
  }
}

class RawWaveFragment {
  const RawWaveFragment({required this.preDelay, this.actions = const []});

  final double preDelay;
  final List<RawWaveAction> actions;

  factory RawWaveFragment.fromJson(Map<String, Object?> json) {
    return RawWaveFragment(
      preDelay: rawDouble(json, 'preDelay'),
      actions: rawListOf(json['actions'], RawWaveAction.fromJson),
    );
  }
}

class RawWaveAction {
  const RawWaveAction({
    required this.actionType,
    required this.key,
    required this.count,
    required this.preDelay,
    required this.interval,
    required this.routeIndex,
    this.hiddenGroup,
    this.randomSpawnGroupKey,
    this.autoPreviewRoute = false,
  });

  /// `SPAWN` (its [key] is an enemy id), `STORY`, `PREVIEW_CURSOR`,
  /// `DISPLAY_ENEMY_INFO`, ...
  final String actionType;
  final String key;
  final int count;
  final double preDelay;
  final double interval;
  final int routeIndex;

  /// Set on actions that only run in some variant of the level.
  final String? hiddenGroup;

  /// Set on actions of which only one of the group spawns.
  final String? randomSpawnGroupKey;

  /// Whether the game shows the route before this spawn.
  final bool autoPreviewRoute;

  bool get isSpawn => actionType == 'SPAWN';

  factory RawWaveAction.fromJson(Map<String, Object?> json) {
    return RawWaveAction(
      actionType: rawString(json, 'actionType'),
      key: rawString(json, 'key'),
      count: rawInt(json, 'count'),
      preDelay: rawDouble(json, 'preDelay'),
      interval: rawDouble(json, 'interval'),
      routeIndex: rawInt(json, 'routeIndex'),
      hiddenGroup: rawOptString(json, 'hiddenGroup'),
      randomSpawnGroupKey: rawOptString(json, 'randomSpawnGroupKey'),
      autoPreviewRoute: rawBool(json, 'autoPreviewRoute'),
    );
  }
}

class RawTokenInst {
  const RawTokenInst({required this.characterKey, required this.position});

  /// Such as `trap_002_emp`.
  final String characterKey;
  final RawGridPosition position;

  factory RawTokenInst.fromJson(Map<String, Object?> json) {
    return RawTokenInst(
      characterKey: rawString(rawMap(json['inst']), 'characterKey'),
      position: RawGridPosition.fromJson(rawMap(json['position'])),
    );
  }
}

class RawLevelRune {
  const RawLevelRune({
    required this.difficultyMask,
    required this.key,
    this.blackboard = const [],
  });

  /// `ALL`, `NORMAL`, `FOUR_STAR`, `EASY`, ...: the stage difficulties (or
  /// difficulty groups) the rune applies to.
  final String difficultyMask;
  final String key;
  final List<RawBlackboard> blackboard;

  factory RawLevelRune.fromJson(Map<String, Object?> json) {
    return RawLevelRune(
      difficultyMask: rawString(json, 'difficultyMask'),
      key: rawString(json, 'key'),
      blackboard: rawListOf(json['blackboard'], RawBlackboard.fromJson),
    );
  }
}
