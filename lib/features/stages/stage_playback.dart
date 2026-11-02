import 'dart:math' as math;

import '../../domain/stage.dart';

/// An enemy on the map at a moment of the playback.
class EnemyOnMap {
  const EnemyOnMap({
    required this.row,
    required this.col,
    required this.spawn,
    required this.enemy,
  });

  /// Tile coordinates of its centre (row counted from the bottom); between
  /// tiles while it moves.
  final double row;
  final double col;
  final StageSpawn spawn;
  final StageEnemy? enemy;
}

/// Where a stage's enemies are at any time, estimated from the spawn
/// schedule, the paths and each enemy's move speed: an enemy walks
/// `moveSpeed × moveMultiplier` tiles a second, waits where its path says,
/// and leaves the map at the end of its path. Nobody blocks or kills it.
class StagePlayback {
  StagePlayback(this.detail)
      : _enemies = {for (final enemy in detail.enemies) enemy.enemyId: enemy};

  final StageDetail detail;
  final Map<String, StageEnemy> _enemies;
  final _timings = <String, _PathTiming>{};

  /// Seconds until the last enemy leaves the map (or, for enemies that
  /// never move, until the last spawn).
  late final double duration = () {
    var end = detail.lastSpawnTime;
    for (final spawn in detail.spawns) {
      final timing = _timing(spawn);
      final last = spawn.time + spawn.interval * (spawn.count - 1);
      if (timing.total.isFinite) {
        end = math.max(end, last + timing.total);
      }
    }
    return end;
  }();

  /// The enemies on the map at [time], those of [laneIndex] only when it
  /// is set.
  List<EnemyOnMap> enemiesAt(double time, {int? laneIndex}) {
    final result = <EnemyOnMap>[];
    for (final spawn in detail.spawns) {
      if (spawn.time > time) {
        continue;
      }
      if (laneIndex != null &&
          detail.paths[spawn.pathIndex].laneIndex != laneIndex) {
        continue;
      }
      final timing = _timing(spawn);
      for (var i = 0; i < spawn.count; i++) {
        final elapsed = time - (spawn.time + spawn.interval * i);
        if (elapsed < 0) {
          break;
        }
        final position = timing.at(elapsed);
        if (position == null) {
          continue;
        }
        result.add(
          EnemyOnMap(
            row: position.$1,
            col: position.$2,
            spawn: spawn,
            enemy: _enemies[spawn.enemyId],
          ),
        );
      }
    }
    return result;
  }

  /// The spawns still to come after [time], soonest first.
  Iterable<StageSpawn> spawnsAfter(double time) =>
      detail.spawns.where((spawn) => spawn.time > time);

  _PathTiming _timing(StageSpawn spawn) {
    final speed = (_enemies[spawn.enemyId]?.stats.moveSpeed ?? 1) *
        detail.options.moveMultiplier;
    return _timings.putIfAbsent(
      '${spawn.pathIndex}/$speed',
      () => _PathTiming(detail.paths[spawn.pathIndex].steps, speed),
    );
  }
}

/// When an enemy of one speed reaches each step of a path.
class _PathTiming {
  _PathTiming(List<PathStep> steps, double speed) {
    var time = 0.0;
    for (final (index, step) in steps.indexed) {
      if (index > 0 && !step.jump) {
        final before = steps[index - 1].position;
        final distance = math.sqrt(
          math.pow(step.position.row - before.row, 2) +
              math.pow(step.position.col - before.col, 2),
        );
        time += speed > 0 ? distance / speed : double.infinity;
      }
      _arrive.add(time);
      time += step.wait;
      _leave.add(time);
      _steps.add(step);
    }
    total = time;
  }

  final _steps = <PathStep>[];
  final _arrive = <double>[];
  final _leave = <double>[];

  /// Seconds from spawning to leaving the map; infinite when it never
  /// moves.
  late final double total;

  /// The position [elapsed] seconds after spawning; null once it has left.
  (double, double)? at(double elapsed) {
    if (_steps.isEmpty || elapsed > total) {
      return null;
    }
    for (var i = 0; i < _steps.length; i++) {
      final here = _steps[i].position;
      if (elapsed <= _leave[i]) {
        if (elapsed >= _arrive[i] || i == 0) {
          return (here.row.toDouble(), here.col.toDouble());
        }
        // On its way from the step before.
        final before = _steps[i - 1].position;
        final span = _arrive[i] - _leave[i - 1];
        final t = span <= 0 ? 1.0 : (elapsed - _leave[i - 1]) / span;
        return (
          before.row + (here.row - before.row) * t,
          before.col + (here.col - before.col) * t,
        );
      }
    }
    return null;
  }
}
