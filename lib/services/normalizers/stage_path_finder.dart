import 'dart:math' as math;

import '../../domain/stage.dart';
import '../../raw_models/level_data.dart';

/// Turns a level route into the tiles its enemy passes, the way PRTS.Map
/// draws routes: the shortest way between consecutive checkpoints for
/// walking enemies, straight lines for flying ones.
///
/// What the game does between two checkpoints is not in the data. Of the
/// walking routes this finds a way for all but a few dozen segments of
/// every region's levels (`test/full_data`); where it finds none it joins
/// the checkpoints with a straight line as PRTS.Map does.
class StagePathFinder {
  const StagePathFinder(this.map);

  final StageMap map;

  /// Checkpoints that hold the enemy where it is until a point of the
  /// wave's schedule.
  static const _scheduleWaits = {
    'WAIT_CURRENT_FRAGMENT_TIME',
    'WAIT_CURRENT_WAVE_TIME',
    'WAIT_BOSSRUSH_WAVE',
  };

  /// Tiles walking enemies never cross, whatever their passable mask says
  /// (`tile_hole` only on routes that do not visit every checkpoint).
  static const _blockedForWalking = {'tile_empty', 'tile_fence_bound'};

  List<PathStep> steps(RawLevelRoute route) {
    final walking = route.motionMode != 'FLY';
    final steps = <_Step>[_Step(_position(route.startPosition))];
    var jumpNext = false;
    var patrols = false;

    void moveTo(GridPosition target) {
      if (jumpNext) {
        steps.add(_Step(target, jump: true));
        jumpNext = false;
        return;
      }
      final from = steps.last.position;
      if (from == target) {
        return;
      }
      final way = walking ? _shortestWay(from, target, route) : null;
      if (way == null) {
        steps.add(_Step(target));
        return;
      }
      for (final position in way.skip(1)) {
        steps.add(_Step(position));
      }
    }

    for (final checkpoint in route.checkpoints) {
      switch (checkpoint.type) {
        case 'WAIT_FOR_SECONDS':
          steps.last.wait += checkpoint.time;
        case 'DISAPPEAR':
          jumpNext = true;
        case 'APPEAR_AT_POS':
          jumpNext = true;
          moveTo(_position(checkpoint.position));
        case 'PATROL_MOVE':
          patrols = true;
          moveTo(_position(checkpoint.position));
        case 'ALERT':
          // Marks where the enemy is; it does not move it.
          break;
        default:
          if (_scheduleWaits.contains(checkpoint.type)) {
            steps.last.waitsForSchedule = true;
          } else {
            moveTo(_position(checkpoint.position));
          }
      }
    }
    // A patrolling enemy walks its checkpoints and never heads for the end.
    if (!patrols) {
      moveTo(_position(route.endPosition));
    }

    return [
      for (final step in steps)
        PathStep(
          position: step.position,
          wait: step.wait,
          jump: step.jump,
          waitsForSchedule: step.waitsForSchedule,
        ),
    ];
  }

  bool _inside(GridPosition position) =>
      position.row >= 0 &&
      position.row < map.height &&
      position.col >= 0 &&
      position.col < map.width;

  bool _walkable(GridPosition position, RawLevelRoute route) {
    if (!_inside(position)) {
      return false;
    }
    final tile = map.tileAt(position);
    if (tile.passableMask != 'ALL' && tile.passableMask != 'WALK_ONLY') {
      return false;
    }
    if (_blockedForWalking.contains(tile.tileKey)) {
      return false;
    }
    return route.visitEveryCheckPoint || tile.tileKey != 'tile_hole';
  }

  /// Dijkstra over the grid: unit steps, √2 diagonals that do not cut a
  /// blocked corner. Only the tiles between [from] and [to] must be
  /// walkable: an enemy may come out of a hole or go into one. Null when no
  /// way connects them. Ties go to the neighbour found first (rows, then
  /// columns, ascending), so the result is stable.
  List<GridPosition>? _shortestWay(
    GridPosition from,
    GridPosition to,
    RawLevelRoute route,
  ) {
    if (!_inside(from) || !_inside(to)) {
      return null;
    }
    int key(GridPosition position) => position.row * map.width + position.col;
    final distance = <int, double>{key(from): 0};
    final previous = <int, GridPosition>{};
    final done = <int>{};
    final open = <GridPosition>[from];

    while (open.isNotEmpty) {
      var best = 0;
      for (var i = 1; i < open.length; i++) {
        if (distance[key(open[i])]! < distance[key(open[best])]! - 1e-9) {
          best = i;
        }
      }
      final current = open.removeAt(best);
      if (current == to) {
        final way = [to];
        while (way.last != from) {
          way.add(previous[key(way.last)]!);
        }
        return way.reversed.toList();
      }
      done.add(key(current));
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) {
            continue;
          }
          final diagonal = dr != 0 && dc != 0;
          if (diagonal && !route.allowDiagonalMove) {
            continue;
          }
          final next = GridPosition(
            row: current.row + dr,
            col: current.col + dc,
          );
          if (done.contains(key(next)) ||
              (next != to && !_walkable(next, route))) {
            continue;
          }
          if (diagonal &&
              !(_walkable(
                    GridPosition(row: current.row + dr, col: current.col),
                    route,
                  ) &&
                  _walkable(
                    GridPosition(row: current.row, col: current.col + dc),
                    route,
                  ))) {
            continue;
          }
          final cost = distance[key(current)]! + (diagonal ? math.sqrt2 : 1);
          final known = distance[key(next)];
          if (known == null || cost < known - 1e-9) {
            if (known == null) {
              open.add(next);
            }
            distance[key(next)] = cost;
            previous[key(next)] = current;
          }
        }
      }
    }
    return null;
  }

  static GridPosition _position(RawGridPosition raw) =>
      GridPosition(row: raw.row, col: raw.col);
}

class _Step {
  _Step(this.position, {this.jump = false});

  final GridPosition position;
  final bool jump;
  double wait = 0;
  bool waitsForSchedule = false;
}
